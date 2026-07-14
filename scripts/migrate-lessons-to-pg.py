#!/usr/bin/env python3
"""
TKT-0362: Migrate markdown lessons into PG state_lessons + entity_links.
Pure-Python driver handles:
- Phase A: Lessons with bodies from memory/LESSONS.md and legacy daily memory files.
- Phase B: Stub rows for lesson IDs referenced in entity_links but missing bodies.
- Entity links from lesson `Linked:` sections.
- Idempotent upsert by lesson_id.
"""

import hashlib
import json
import re
import subprocess
import sys
from collections import defaultdict
from datetime import datetime
from pathlib import Path

import shutil
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
    raise RuntimeError("psql not found")

PSQL = _psql_bin()


DB_NAME = "ainchors_nexus"
DB_USER = os.environ.get("PGUSER", "")
DB_HOST = "127.0.0.1"
WORKSPACE = Path("/Users/ainchorsoc2a/.openclaw/workspace")
LESSONS_FILE = WORKSPACE / "memory/LESSONS.md"


def psql(sql, capture=True):
    cmd = [PSQL, "-h", DB_HOST, "-U", DB_USER, "-d", DB_NAME, "-t", "-A"]
    if not capture:
        cmd.extend(["-c", sql])
        return subprocess.run(cmd, capture_output=False).returncode
    cmd.extend(["-c", sql])
    r = subprocess.run(cmd, capture_output=True, text=True)
    if r.returncode != 0:
        print(f"PG ERROR: {r.stderr.strip()}", file=sys.stderr)
    return r.stdout.strip()


def ensure_schema():
    psql("""
        CREATE TABLE IF NOT EXISTS public.state_lessons (
            lesson_id    TEXT NOT NULL PRIMARY KEY,
            ts           TIMESTAMPTZ DEFAULT now(),
            title        TEXT,
            body         TEXT,
            source       TEXT,
            category     TEXT,
            status       TEXT DEFAULT 'active',
            fix          TEXT,
            evidence     TEXT,
            prevention   TEXT,
            metadata     JSONB DEFAULT '{}',
            tenant_id    TEXT DEFAULT 'ainchors'
        );
    """, capture=False)
    for idx in [
        "idx_state_lessons_source ON state_lessons(source)",
        "idx_state_lessons_category ON state_lessons(category)",
        "idx_state_lessons_status ON state_lessons(status)",
    ]:
        psql(f"CREATE INDEX IF NOT EXISTS {idx};", capture=False)


def target_type(link):
    if link.startswith("TKT-"): return "ticket"
    if link.startswith("CHG-"): return "chg"
    if link.startswith("L-"): return "lesson"
    if link.startswith("INC-"): return "incident"
    if link.startswith("CR-"): return "cr"
    return "file"


def safe(text):
    return text.replace("'", "''")


def extract_links(body_text):
    """Extract link IDs from **Linked:** section."""
    links = []
    lk = re.search(r'\*\*Linked:\*\*\s*(.*)', body_text)
    if lk:
        raw = lk.group(1).strip()
        parts = re.split(r',\s*(?![^\(]*\))', raw)
        for p in parts:
            p = p.strip()
            p = re.sub(r'\s*\([^)]*\)\s*$', '', p).strip()
            p = re.sub(r'[.,;:!?\(\)]+$', '', p).strip()
            if re.match(r'^(TKT-\d+|CHG-\d+|L-\d+|INC-\d{8}-\d+|CR-\d+)$', p):
                links.append(p)
    return links


# ── Phase A: Parse structured LESSONS.md ─────────────────────────────────

def parse_structured_lessons():
    """Parse ## L-NNN — Title format."""
    content = LESSONS_FILE.read_text()
    blocks = re.split(r'^##\s+', content, flags=re.MULTILINE)
    entries = []
    linked_pairs = defaultdict(list)

    for block in blocks[1:]:
        if not block.strip():
            continue
        lines = block.splitlines()
        header = lines[0]
        m = re.match(r'^(L-\d+)\s+[—\-]\s+(.+)$', header)
        if not m:
            continue
        lesson_id = m.group(1).strip()
        title = m.group(2).strip()
        body = "\n".join(lines[1:])

        date = _extract_field(body, r'\*\*Date:\*\*\s*(\d{4}-\d{2}-\d{2})')
        source = _extract_field(body, r'\*\*Source:\*\*\s*(.+?)(?:\n|$)')
        fix = _extract_field(body, r'\*\*Fix:\*\*\s*(.+?)(?:\n\*\*|\Z)', dotall=True)
        evidence = _extract_field(body, r'\*\*Evidence:\*\*\s*(.+?)(?:\n\*\*|\Z)', dotall=True)
        prevention = _extract_field(body, r'\*\*Prevention:\*\*\s*(.+?)(?:\n\*\*|\Z)', dotall=True)

        lesson_body = ""
        lm = re.search(r'\*\*Lesson:\*\*\s*(.+?)(?:\n\*\*Fix:|\n\*\*Evidence:|\n\*\*Prevention:|\n\*\*Linked:|\Z)', body, re.DOTALL)
        if lm:
            lesson_body = lm.group(1).strip()
        else:
            pre_fix = body[:body.find("**Fix:**")] if "**Fix:**" in body else body
            pre_fix = re.sub(r'\*\*Date:\*\*.*?\n', '', pre_fix)
            pre_fix = re.sub(r'\*\*Source:\*\*.*?\n', '', pre_fix)
            lesson_body = pre_fix.strip()

        links = extract_links(body)
        for link in links:
            linked_pairs[lesson_id].append(link)

        entries.append(dict(lesson_id=lesson_id, ts=f"{date} 00:00 UTC" if date else None,
                           title=title, body=lesson_body, source=source, category="",
                           fix=fix, evidence=evidence, prevention=prevention, links=links))
    return entries, dict(linked_pairs)


def _extract_field(body, pattern, dotall=False):
    flags = re.DOTALL if dotall else 0
    m = re.search(pattern, body, flags)
    return m.group(1).strip() if m else ""


# ── Phase A: Freeform in LESSONS.md ──────────────────────────────────────

def parse_freeform_lessons():
    """Parse bold-text headers: **YYYY-MM-DD | Category | Title** (no L-NNN)."""
    content = LESSONS_FILE.read_text()
    entries = []

    matches = list(re.finditer(
        r'^\*{2}(\d{4}-\d{2}-\d{2}\s*\|\s*\S+\s*\|\s*.+?)\*{2}\s*$',
        content, re.MULTILINE
    ))
    for i, m in enumerate(matches):
        header = m.group(1).strip()
        body_text = content[m.end():matches[i + 1].start() if i + 1 < len(matches) else len(content)].strip()
        h = re.match(r'^(\d{4}-\d{2}-\d{2})\s*\|\s*(\S+)\s*\|\s*(.+)$', header)
        if not h:
            continue
        date, category, title = h.groups()
        title = title.strip()

        lesson_id = "L-FREEFORM-" + hashlib.md5(f"{date}-{title}".encode()).hexdigest()[:8]
        what = evidence = prevention = source = ""

        for label, var in [("What", "what"), ("Impact", "_"), ("Prevention", "prevention"),
                           ("Evidence", "evidence"), ("Source", "source")]:
            mf = re.search(rf'\*{0,2}{label}:\*{0,2}\s*(.+?)(?:\n\s*[-*]\s*\*?[A-Z]\w+:|\n\s*\*{{2}}|\Z)', body_text, re.DOTALL)
            what = evidence = prevention = source = impact = ""

            for label, var in [("What", "what"), ("Impact", "impact"), ("Prevention", "prevention"),
                               ("Evidence", "evidence"), ("Source", "source")]:
                mf = re.search(rf'\*{{0,2}}{label}:\*{{0,2}}\s*(.+?)(?:\n\s*[-*]\s*\*?[A-Z]\w+:|\n\s*\*{{2}}|\Z)', body_text, re.DOTALL)
                if mf:
                    val = mf.group(1).strip()
                    if var == "what": what = val
                    elif var == "impact": impact = val
                    elif var == "prevention": prevention = val
                    elif var == "evidence": evidence = val
                    elif var == "source": source = val

            links = extract_links(body_text)
            full_body = "\n".join(filter(None, [f"What: {what}" if what else "", f"Impact: {impact}" if impact else ""]))

        entries.append(dict(lesson_id=lesson_id, ts=f"{date} 00:00 UTC",
                           title=title, body=full_body, source=source, category=category,
                           fix="", evidence=evidence, prevention=prevention, links=links))
    return entries


# ── Phase A: Legacy daily memory lessons ─────────────────────────────────

def find_legacy_lessons():
    memory_dir = WORKSPACE / "memory"
    entries = []
    linked_pairs = defaultdict(list)

    for fpath in sorted(memory_dir.glob("*.md")):
        fname = fpath.name
        if fname in ("LESSONS.md",) or fname.startswith("CHANGELOG") or fname.startswith("journal-"):
            continue
        content = fpath.read_text()
        found_ids = set()

        blocks = re.split(r'^##\s+', content, flags=re.MULTILINE)
        for block in blocks[1:]:
            if not block.strip():
                continue
            lines = block.splitlines()
            header = lines[0]
            body_text = "\n".join(lines[1:])

            # Pattern 1: L-NNN | Title or L-NNN — Title
            m = re.match(r'^(L-\d+)\s*[|\-—]\s*(.+)$', header)
            if not m:
                # Pattern 2: L-NNN (Logged), L-NNN Logged, L-NNN (To Log Next Session)
                m = re.match(r'^(L-\d+)(?:\s+\((?:Logged|Pending|To Log Next Session)\)|\s+Logged|\s+Pending)?\s*$', header)
                if not m:
                    continue
                lesson_id = m.group(1)
                # Get title from first data line: - YYYY-MM-DD | Category | Title
                tm = re.search(r'^-\s+\d{4}-\d{2}-\d{2}\s+\|\s+\S+\s+\|\s+(.+?)$', body_text, re.MULTILINE)
                title = tm.group(1).strip() if tm else lesson_id
            else:
                lesson_id = m.group(1).strip()
                title = m.group(2).strip()

            if lesson_id in found_ids:
                continue
            found_ids.add(lesson_id)

            date = _extract_field(body_text, r'\*\*Date:\*\*\s*(\d{4}-\d{2}-\d{2})')
            source = _extract_field(body_text, r'\*\*Source:\*\*\s*(.+?)(?:\n|$)')
            category = _extract_field(body_text, r'\*\*Category:\*\*\s*(.+?)(?:\n|$)')
            fix = _extract_field(body_text, r'\*\*Fix:\*\*\s*(.+?)(?:\n\*\*|\Z)', dotall=True)
            evidence = _extract_field(body_text, r'\*\*Evidence:\*\*\s*(.+?)(?:\n\*\*|\Z)', dotall=True)
            prevention = _extract_field(body_text, r'\*\*Prevention:\*\*\s*(.+?)(?:\n\*\*|\Z)', dotall=True)

            lesson_body = ""
            lm = re.search(r'\*\*Lesson:\*\*\s*(.+?)(?:\n\*\*|\Z)', body_text, re.DOTALL)
            if lm:
                lesson_body = lm.group(1).strip()
            else:
                field_lines = re.findall(r'^\*\*[^*]+\*\*', body_text, re.MULTILINE)
                if field_lines:
                    first = body_text.index(field_lines[0])
                    lesson_body = body_text[:first].strip()
                else:
                    lesson_body = body_text.strip()

            # For bullet-list format (L-065, L-066), body is the bullet content
            bullets = re.findall(r'^-\s+(.+)$', body_text, re.MULTILINE)
            if bullets and not lesson_body:
                lesson_body = "\n".join(bullets)

            links = extract_links(body_text)
            for link in links:
                linked_pairs[lesson_id].append(link)

            entries.append(dict(lesson_id=lesson_id, ts=f"{date} 00:00 UTC" if date else None,
                               title=title, body=lesson_body, source=source, category=category,
                               fix=fix, evidence=evidence, prevention=prevention, links=links))
    return entries, dict(linked_pairs)


# ── Phase B: Stub IDs ────────────────────────────────────────────────────

def find_stub_lesson_ids(phase_a_ids):
    known_raw = psql("""
        SELECT DISTINCT to_id FROM entity_links WHERE to_type = 'lesson'
        UNION
        SELECT DISTINCT from_id FROM entity_links WHERE from_type = 'lesson'
    """)
    ref_ids = set()
    if known_raw:
        for line in known_raw.strip().split('\n'):
            line = line.strip()
            if re.match(r'^L-\d+$', line):
                ref_ids.add(line)

    existing_raw = psql("SELECT lesson_id FROM state_lessons")
    existing = set()
    if existing_raw:
        for line in existing_raw.strip().split('\n'):
            existing.add(line.strip())

    stub = (ref_ids | set(phase_a_ids)) - existing
    # Remove freeform IDs
    stub = {s for s in stub if not s.startswith("L-FREEFORM-")}
    return sorted(stub, key=lambda x: int(x.split('-')[1]))


# ── Main ─────────────────────────────────────────────────────────────────

def migrate(dry_run=False):
    batch_id = f"MIG-TKT-0362-{datetime.now().strftime('%Y%m%d%H%M')}"

    if not dry_run:
        ensure_schema()

    structured, slinks = parse_structured_lessons()
    freeform = parse_freeform_lessons()
    legacy, llinks = find_legacy_lessons()

    phase_a = structured + freeform + legacy
    phase_a_ids = set(e["lesson_id"] for e in phase_a)

    all_links = defaultdict(list)
    for d in (slinks, llinks):
        for k, v in d.items():
            all_links[k].extend(v)

    print(f"Phase A: {len(structured)} structured + {len(freeform)} freeform + {len(legacy)} legacy = {len(phase_a)} total")
    for e in phase_a:
        print(f"  [{e['lesson_id']}] {e['title'][:80]}")

    if not dry_run:
        stub_ids = find_stub_lesson_ids(phase_a_ids)
    else:
        stub_ids = list(phase_a_ids - {e["lesson_id"] for e in phase_a if e["lesson_id"].startswith("L-FREEFORM-")})

    phase_a_inserted = 0
    for e in phase_a:
        metadata = json.dumps(dict(migration_batch=batch_id, phase="A"), separators=(',', ':'))
        ts_val = f"'{e['ts']}'" if e["ts"] else "now()"
        sql = (
            "INSERT INTO state_lessons "
            "(lesson_id, ts, title, body, source, category, status, fix, evidence, prevention, metadata) "
            f"VALUES ('{safe(e['lesson_id'])}', {ts_val}, '{safe(e['title'])}', '{safe(e.get('body',''))}', "
            f"'{safe(e.get('source',''))}', '{safe(e.get('category',''))}', 'active', "
            f"'{safe(e.get('fix',''))}', '{safe(e.get('evidence',''))}', '{safe(e.get('prevention',''))}', "
            f"'{metadata.replace(chr(39), chr(39)+chr(39))}') "
            "ON CONFLICT (lesson_id) DO UPDATE SET "
            "ts = EXCLUDED.ts, title = EXCLUDED.title, body = EXCLUDED.body, "
            "source = EXCLUDED.source, category = EXCLUDED.category, "
            "fix = EXCLUDED.fix, evidence = EXCLUDED.evidence, "
            "prevention = EXCLUDED.prevention, "
            "metadata = state_lessons.metadata || EXCLUDED.metadata;"
        )
        if dry_run:
            print(f"  [DRY-RUN] UPSERT: {e['lesson_id']}")
        else:
            psql(sql, capture=False)
            phase_a_inserted += 1

    phase_b_inserted = 0
    for lid in stub_ids:
        meta = json.dumps(dict(migration_batch=batch_id, phase="B", source="entity_links_reference_only"), separators=(',', ':'))
        meta_safe = meta.replace("'", "''")
        sql = (
            "INSERT INTO state_lessons "
            "(lesson_id, ts, title, body, source, category, status, metadata) "
            f"VALUES ('{lid}', now(), NULL, NULL, NULL, NULL, 'stub', '{meta_safe}') "
            "ON CONFLICT (lesson_id) DO NOTHING;"
        )
        if dry_run:
            print(f"  [DRY-RUN] STUB: {lid}")
        else:
            psql(sql, capture=False)
            phase_b_inserted += 1

    linked_count = 0
    for lid, links in all_links.items():
        for link in links:
            if link == lid:
                continue
            src = f"migrated-from-md:{batch_id}"
            sql = (
                "INSERT INTO entity_links "
                "(link_id, from_type, from_id, to_type, to_id, link_type, source) "
                f"VALUES (nextval('entity_links_link_id_seq'), 'lesson', '{safe(lid)}', "
                f"'{target_type(link)}', '{safe(link)}', "
                f"'relates-to', '{src}') "
                "ON CONFLICT ON CONSTRAINT entity_links_upsert_key DO NOTHING;"
            )
            if dry_run:
                print(f"  [DRY-RUN] LINK: {lid} → {link}")
            else:
                psql(sql, capture=False)
                linked_count += 1

    # Reverse links: CHG→lesson → lesson→CHG
    if not dry_run:
        psql(
            "INSERT INTO entity_links (link_id, from_type, from_id, to_type, to_id, link_type, source) "
            "SELECT nextval('entity_links_link_id_seq'), 'lesson', e.to_id, 'chg', e.from_id, 'relates-to', "
            f"  'reverse-link:TKT-0362:{batch_id}' "
            "FROM entity_links e "
            "WHERE e.to_type = 'lesson' AND e.from_type = 'chg' "
            "AND NOT EXISTS ("
            "  SELECT 1 FROM entity_links e2 "
            "  WHERE e2.from_type = 'lesson' AND e2.from_id = e.to_id "
            "  AND e2.to_type = 'chg' AND e2.to_id = e.from_id"
            ")"
            "ON CONFLICT ON CONSTRAINT entity_links_upsert_key DO NOTHING;",
            capture=False
        )

    report = dict(
        batch_id=batch_id, phase_a_structured=len(structured),
        phase_a_freeform=len(freeform), phase_a_legacy=len(legacy),
        phase_a_total=len(phase_a), phase_a_inserted=phase_a_inserted,
        phase_b_stub_count=len(stub_ids), phase_b_inserted=phase_b_inserted,
        links_created=linked_count, dry_run=dry_run,
        status="DRY_RUN" if dry_run else "MIGRATED",
    )
    (WORKSPACE / "state/TKT-0362-migration-report.json").write_text(json.dumps(report, indent=2))
    print(json.dumps(report, indent=2))
    return report


if __name__ == "__main__":
    migrate("--dry-run" in sys.argv)
