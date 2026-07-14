#!/usr/bin/env python3
"""
TKT-0721: Migrate markdown CHGs into PG state_changes + entity_links.
Pure-Python driver avoids shell escaping issues.
"""

import json
import os
import re
import shutil
import subprocess
import sys
from datetime import datetime
from pathlib import Path


def _psql_bin():
    p = shutil.which("psql") or os.environ.get("PSQL_BIN")
    if p:
        return p
    try:
        prefix = subprocess.check_output(["brew", "--prefix"], text=True).strip()
        candidate = os.path.join(prefix, "bin", "psql")
        if os.path.isfile(candidate) and os.access(candidate, os.X_OK):
            return candidate
    except Exception:
        pass
    raise RuntimeError("psql not found in PATH, PSQL_BIN, or brew prefix")


PSQL = _psql_bin()

DB_NAME = "ainchors_nexus"
DB_USER = os.environ.get("PGUSER") or ""
DB_HOST = "127.0.0.1"


def psql(sql):
    return subprocess.run(
        [PSQL, "-h", DB_HOST, "-U", DB_USER, "-d", DB_NAME, "-t", "-A", "-c", sql],
        capture_output=True, text=True, check=True,
    ).stdout


def parse_files():
    files = [
        ("memory/CHANGELOG.md", "memory/CHANGELOG.md"),
        ("docs/CHANGELOG.md", "docs/CHANGELOG.md"),
        ("archive/CHANGELOG.md", "archive/CHANGELOG.md"),
    ]
    source_mtime = {}
    for path, _ in files:
        try:
            source_mtime[path] = datetime.fromtimestamp(os.path.getmtime(path)).isoformat()
        except OSError:
            source_mtime[path] = None

    failures = []
    seen_ids = {}
    entries = []

    for path, src_label in files:
        content = Path(path).read_text()
        blocks = re.split(r'^##\s+', content, flags=re.MULTILINE)
        for block in blocks[1:]:
            if not block.strip():
                continue
            lines = block.splitlines()
            header = lines[0]
            body = "\n".join(lines[1:])

            m1 = re.search(r'^(\d{4}-\d{2}-\d{2}\s\d{2}:\d{2}\s[A-Za-z]+)\s+—\s+\[(CHG-\d+)\]\s+(.+)$', header)
            m2 = re.search(r'^(?:\[)?(CHG-\d+)(?:\])?\s+—\s+(.+)$', header)
            m3 = re.search(r'^(\d{4}-\d{2}-\d{2})$', header.strip())

            chg_id = ts = title = None
            if m1:
                ts, chg_id, title = m1.groups()
            elif m2:
                chg_id, title = m2.groups()
                dm = re.search(r'-\s*\*\*Date:\*\*\s*(\d{4}-\d{2}-\d{2})', body)
                if dm:
                    ts = dm.group(1) + " 00:00 UTC"
                else:
                    ts = source_mtime.get(path)
            elif m3:
                ts = m3.group(1) + " 00:00 UTC"
                clean_date = m3.group(1).replace('-', '')
                chg_id = f"CHG-ARCHIVE-{clean_date}-1"
                title = header.strip()
            else:
                continue

            if chg_id in seen_ids:
                failures.append(f"duplicate_skipped:{chg_id}:{header}")
                continue
            seen_ids[chg_id] = True

            links = []
            lm = re.search(r'\*\*Linked:\*\*\s*(.*)', body, re.IGNORECASE)
            if lm:
                raw = lm.group(1)
                parts = re.split(r',\s*(?![^\(]*\))', raw)
                for p in parts:
                    p = p.strip()
                    p = re.sub(r'\s*\([^)]*\)\s*$', '', p).strip()
                    p = re.sub(r'[.,;:!?\(\)]+$', '', p).strip()
                    if re.match(r'^(TKT-\d+|CHG-\d+|L-\d+|INC-\d{8}-\d+|CR-\d+)$', p):
                        links.append(p)
                    elif ('/' in p or '.' in p) and len(p) > 2:
                        links.append(p.rstrip('.,;:!?'))

            entries.append({
                "chg_id": chg_id,
                "ts": ts,
                "title": title,
                "description": body,
                "src": src_label,
                "links": links,
            })

    return entries, failures, seen_ids


def target_type(link):
    if link.startswith("TKT-"): return "ticket"
    if link.startswith("CHG-"): return "chg"
    if link.startswith("L-"): return "lesson"
    if link.startswith("INC-"): return "incident"
    if link.startswith("CR-"): return "cr"
    return "file"


def run_migration():
    batch_id = f"MIG-TKT-0721-{datetime.now().strftime('%Y%m%d%H%M')}"
    entries, failures, seen_ids = parse_files()

    print(json.dumps({
        "batch_id": batch_id,
        "source_files": ["memory/CHANGELOG.md", "docs/CHANGELOG.md", "archive/CHANGELOG.md"],
        "parsed_entries": len(entries),
        "unique_chg_ids": len(seen_ids),
        "duplicate_skipped": len([f for f in failures if f.startswith("duplicate_skipped:")]),
        "other_failures": [f for f in failures if not f.startswith("duplicate_skipped:")],
    }, indent=2))

    inserted = 0
    linked = 0

    for e in entries:
        metadata = json.dumps({"source_file": e["src"], "migration_batch": batch_id}, separators=(',', ':'))
        ts_val = "NULL" if e["ts"] is None else f"'{e['ts']}'"
        title = e["title"].replace("'", "''")
        desc = e["description"].replace("'", "''")
        sql = (
            "INSERT INTO state_changes (change_id, ts, title, description, status, metadata) "
            f"VALUES ('{e['chg_id']}', {ts_val}, '{title}', '{desc}', 'migrated_shadow', '{metadata}') "
            "ON CONFLICT (change_id) DO NOTHING;"
        )
        psql(sql)
        inserted += 1

        for link in e["links"]:
            if link == e["chg_id"]:
                continue  # skip self-referential CHG links
            safe_link = link.replace("'", "''")
            lsql = (
                "INSERT INTO entity_links (link_id, from_type, from_id, to_type, to_id, link_type, source) "
                f"VALUES (gen_random_uuid(), 'CHG', '{e['chg_id']}', '{target_type(link)}', '{safe_link}', "
                f"'relates-to', 'migrated-from-md:{e['src']}') "
                "ON CONFLICT ON CONSTRAINT entity_links_upsert_key DO NOTHING;"
            )
            psql(lsql)
            linked += 1

    psql(f"UPDATE state_changes SET status = NULL WHERE metadata->>'migration_batch' = '{batch_id}';")

    pre_count = int(psql("SELECT count(*) FROM state_changes WHERE metadata->>'migration_batch' IS DISTINCT FROM '{batch_id}';".replace('{batch_id}', batch_id)).strip() or 0)
    post_count = int(psql("SELECT count(*) FROM state_changes;").strip() or 0)
    inserted_net = post_count - pre_count

    # Only count CHGs that actually have standalone markdown headers
    files = ["memory/CHANGELOG.md", "docs/CHANGELOG.md", "archive/CHANGELOG.md"]
    all_md_chgs = set()
    for path in files:
        try:
            content = Path(path).read_text()
        except FileNotFoundError:
            continue
        blocks = re.split(r'^##\s+', content, flags=re.MULTILINE)
        for block in blocks[1:]:
            if not block.strip():
                continue
            header = block.splitlines()[0]
            m1 = re.search(r'^(\d{4}-\d{2}-\d{2}\s\d{2}:\d{2}\s[A-Za-z]+)\s+—\s+\[(CHG-\d+)\]\s+(.+)$', header)
            m2 = re.search(r'^(?:\[)?(CHG-\d+)(?:\])?\s+—\s+(.+)$', header)
            if m1:
                all_md_chgs.add(m1.group(2))
            elif m2:
                all_md_chgs.add(m2.group(1))

    total_md_unique = len(all_md_chgs)
    pg_chg_count = int(psql("SELECT count(DISTINCT change_id) FROM state_changes;").strip() or 0)

    gaps = 0
    missing = []
    for chg_id in sorted(all_md_chgs, key=lambda x: int(x.split('-')[1])):
        exists = psql(f"SELECT 1 FROM state_changes WHERE change_id = '{chg_id}';").strip()
        if not exists:
            gaps += 1
            missing.append(chg_id)

    completeness_pass = (gaps == 0 and pg_chg_count >= total_md_unique)

    report = {
        "batch_id": batch_id,
        "source_files": ["memory/CHANGELOG.md", "docs/CHANGELOG.md", "archive/CHANGELOG.md"],
        "parsed_count": len(entries),
        "inserted_count": inserted_net,
        "linked_count": linked,
        "failures": len([f for f in failures if not f.startswith("duplicate_skipped:")]),
        "pre_count": pre_count,
        "post_count": post_count,
        "md_unique_count": total_md_unique,
        "pg_chg_count": pg_chg_count,
        "gaps": gaps,
        "missing": missing[:20],
        "completeness_pass": completeness_pass,
    }

    Path("state/TKT-0721-migration-report.json").write_text(json.dumps(report, indent=2))

    print("--- Migration Report ---")
    print(f"Batch: {batch_id}")
    print(f"Parsed entries: {len(entries)}")
    print(f"Net inserted: {inserted_net}")
    print(f"Links emitted: {linked}")
    print(f"Pre-count: {pre_count}")
    print(f"Post-count: {post_count}")
    print(f"md_unique={total_md_unique} pg_chg={pg_chg_count} gaps={gaps} pass={completeness_pass}")


if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "--parse-only":
        entries, failures, seen_ids = parse_files()
        print(json.dumps({
            "parsed_entries": len(entries),
            "unique_chg_ids": len(seen_ids),
            "failures": failures[:50],
        }, indent=2))
    else:
        run_migration()
