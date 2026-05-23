#!/bin/bash
# ingest-memory-to-pg.sh — Chunk and ingest memory/*.md into knowledge_documents/chunks
# Usage: bash scripts/ingest-memory-to-pg.sh [--dry-run]
#
# knowledge_documents: metadata (title, source_path, mime_type)
# knowledge_chunks:     content chunks with token_count and embedding vector(768)

set -e
WORKSPACE="/Users/ainchorsangiefpl/.openclaw/workspace"
MEMORY_DIR="$WORKSPACE/memory"
DRY_RUN=false
[[ "$1" == "--dry-run" ]] && DRY_RUN=true

PSQL=( /opt/homebrew/bin/psql -t -A -q -h /tmp -p 5432 -U ainchorsangiefpl -d ainchors_nexus )

if [[ "$DRY_RUN" == "false" ]]; then
    echo "=== Clearing existing knowledge entries ==="
    "${PSQL[@]}" -c "DELETE FROM knowledge_chunks" 2>/dev/null || true
    "${PSQL[@]}" -c "DELETE FROM knowledge_documents" 2>/dev/null || true
    echo "Done clearing."
else
    echo "=== DRY-RUN MODE (no writes) ==="
fi

exec python3 << 'PYEOF'
import os, subprocess, sys

WORKSPACE = "/Users/ainchorsangiefpl/.openclaw/workspace"
MEMORY_DIR = os.path.join(WORKSPACE, "memory")
PSQL = ["/opt/homebrew/bin/psql", "-t", "-A", "-q", "-h", "/tmp", "-p", "5432",
        "-U", "ainchorsangiefpl", "-d", "ainchors_nexus"]
DRY_RUN = len(sys.argv) > 1 and sys.argv[1] == "--dry-run"

def db_query(sql):
    r = subprocess.run(PSQL + ["-c", sql], capture_output=True, text=True, timeout=30)
    if r.returncode != 0 and r.stderr.strip():
        print(f"  [warn] {r.stderr.strip()[:300]}", file=sys.stderr)
    return r.stdout.strip()

def escape_sql(s):
    return s.replace("'", "''")

def chunk_content(text, min_chunk_len=20):
    chunks = []
    current_title = "preamble"
    current_lines = []
    for line in text.split('\n'):
        if line.startswith('## ') and not line.startswith('### '):
            ct = '\n'.join(current_lines).strip()
            if ct and len(ct) >= min_chunk_len:
                chunks.append((current_title, ct, len(ct.split())))
            current_title = line.strip('# ').strip()[:200]
            current_lines = []
        else:
            current_lines.append(line)
    ct = '\n'.join(current_lines).strip()
    if ct and len(ct) >= min_chunk_len:
        chunks.append((current_title, ct, len(ct.split())))
    if not chunks and text.strip():
        chunks.append(("preamble", text.strip(), len(text.strip().split())))
    return chunks

files = []
for root, dirs, filenames in os.walk(MEMORY_DIR):
    dirs[:] = [d for d in dirs if d != "agents"]
    for fname in sorted(filenames):
        if not fname.endswith('.md'): continue
        if 'MEMORY-archive' in fname: continue
        if '.journal-tmp' in fname: continue
        fp = os.path.join(root, fname)
        files.append((fp, os.path.relpath(fp, WORKSPACE), fname))

doc_count = 0
total_chunks = 0

for fp, rp, fn in files:
    if DRY_RUN:
        print(f"DRY-RUN: Would ingest {rp}")
        continue
    title = fn.replace('.md', '')[:200]
    try:
        with open(fp, 'r', encoding='utf-8') as f:
            content = f.read()
    except Exception as e:
        print(f"  [skip] Cannot read {rp}: {e}", file=sys.stderr)
        continue
    if not content.strip():
        print(f"  [skip] Empty: {rp}")
        continue
    
    doc_id = db_query(
        f"INSERT INTO knowledge_documents (title, source_path, mime_type) "
        f"VALUES ('{escape_sql(title)}', '{escape_sql(rp)}', 'text/markdown') "
        f"RETURNING id"
    )
    if not doc_id:
        print(f"  [skip] Insert failed for {rp}")
        continue
    
    doc_count += 1
    chunks = chunk_content(content)
    
    for i, (ctitle, ctext, wc) in enumerate(chunks):
        db_query(
            f"INSERT INTO knowledge_chunks (document_id, chunk_index, content, token_count) "
            f"VALUES ('{doc_id}', {i}, '{escape_sql(ctext)}', {wc})"
        )
        total_chunks += 1
    
    if doc_count % 10 == 0 or doc_count <= 3:
        print(f"  [{doc_count}] {rp} ({len(chunks)} chunks)")

print(f"\n=== Done: {doc_count} documents, {total_chunks} chunks ===")
PYEOF
