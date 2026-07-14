#!/bin/bash
# memory-search.sh — Full-text search across knowledge_chunks
# Usage: bash scripts/memory-search.sh "search query" [limit]
#
# Searches knowledge_chunks.content using PostgreSQL full-text search.
# Returns matching chunks with document info and relevance ranking.

DB="/Users/ainchorsoc2a/.openclaw/workspace/scripts/db-raw.sh"
QUERY="$1"
LIMIT="${2:-10}"

if [ -z "$QUERY" ]; then
    echo "Usage: bash scripts/memory-search.sh \"search query\" [limit]"
    echo ""
    echo "Examples:"
    echo "  bash scripts/memory-search.sh \"OWL compliance\""
    echo "  bash scripts/memory-search.sh \"database setup\" 20"
    exit 1
fi

echo "=== Searching for: \"$QUERY\" (limit: $LIMIT) ==="
echo ""

bash "$DB" -c "
SELECT 
    d.title AS document,
    d.source_path AS path,
    c.chunk_index,
    ts_rank_cd(
        to_tsvector('english', COALESCE(c.content, '')),
        plainto_tsquery('english', '$QUERY')
    ) AS rank,
    left(c.content, 400) AS snippet
FROM knowledge_chunks c
JOIN knowledge_documents d ON d.id = c.document_id
WHERE to_tsvector('english', COALESCE(c.content, '')) @@ plainto_tsquery('english', '$QUERY')
ORDER BY rank DESC
LIMIT $LIMIT
" -t
