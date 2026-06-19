# Notion API Patterns Reference

Canonical curl/JSON patterns for AInchors Notion integration. Assumes API version `2022-06-28` and auth key at `~/.config/notion/api_key`.

## Auth check

```bash
NOTION_KEY="$(cat ~/.config/notion/api_key 2>/dev/null || echo "")"
[[ -z "$NOTION_KEY" ]] && { echo "Missing Notion API key"; exit 1; }

curl -s "https://api.notion.com/v1/users/me" \
  -H "Authorization: Bearer $NOTION_KEY" \
  -H "Notion-Version: 2022-06-28"
```

Expected success response includes `{"object":"user","type":"person",...}`.

## Query a database with pagination

```bash
DB_ID="34dc1829-53ff-814b-8257-d3a3bf351d44"
NEXT_CURSOR=""
ALL_RESULTS="[]"

while true; do
  BODY="$(jq -n --arg cursor "$NEXT_CURSOR" '{
    page_size: 100,
    start_cursor: (if $cursor == "" then null else $cursor end)
  }')"

  RESP="$(curl -s -X POST "https://api.notion.com/v1/databases/$DB_ID/query" \
    -H "Authorization: Bearer $NOTION_KEY" \
    -H "Notion-Version: 2022-06-28" \
    -H "Content-Type: application/json" \
    -d "$BODY")"

  ALL_RESULTS="$(echo "$ALL_RESULTS" "$RESP" | jq -s '.[0] + (.[1].results // [])')"
  NEXT_CURSOR="$(echo "$RESP" | jq -r '.next_cursor // ""')"
  HAS_MORE="$(echo "$RESP" | jq -r '.has_more // false')"

  [[ "$HAS_MORE" == "true" && -n "$NEXT_CURSOR" ]] || break
  sleep 0.35  # rate limit
 done

echo "$ALL_RESULTS" | jq 'length'
```

## Create a page in Backlog DB

```bash
DB_ID="34dc1829-53ff-814b-8257-d3a3bf351d44"

jq -n --arg db "$DB_ID" \
      --arg title "Sample Ticket" \
      --arg status "Open" \
      --arg priority "Medium" \
      --arg tkt_type "Task" '{
  parent: {database_id: $db},
  properties: {
    "US Title": {title: [{text: {content: $title}}]},
    "Status": {select: {name: $status}},
    "Priority": {select: {name: $priority}},
    "Type": {select: {name: $tkt_type}}
  }
}' > /tmp/notion-create.json

curl -s -X POST "https://api.notion.com/v1/pages" \
  -H "Authorization: Bearer $NOTION_KEY" \
  -H "Notion-Version: 2022-06-28" \
  -H "Content-Type: application/json" \
  -d @/tmp/notion-create.json
```

## Update a page status

```bash
PAGE_ID="PAGE_UUID_HERE"

curl -s -X PATCH "https://api.notion.com/v1/pages/$PAGE_ID" \
  -H "Authorization: Bearer $NOTION_KEY" \
  -H "Notion-Version: 2022-06-28" \
  -H "Content-Type: application/json" \
  -d '{"properties": {"Status": {"select": {"name": "Done"}}}}'
```

## Archive a duplicate page

```bash
PAGE_ID="PAGE_UUID_HERE"

curl -s -X PATCH "https://api.notion.com/v1/pages/$PAGE_ID" \
  -H "Authorization: Bearer $NOTION_KEY" \
  -H "Notion-Version: 2022-06-28" \
  -H "Content-Type: application/json" \
  -d '{"archived": true}'
```

## Handle HTTP 429

```bash
retry_with_backoff() {
  local url="$1"
  local body="$2"
  local retries=3
  local i=0

  while [[ $i -lt $retries ]]; do
    local resp
    resp="$(curl -s -w "\nHTTP_CODE:%{http_code}" -X POST "$url" \
      -H "Authorization: Bearer $NOTION_KEY" \
      -H "Notion-Version: 2022-06-28" \
      -H "Content-Type: application/json" \
      -d "$body")"

    local code
    code="$(echo "$resp" | grep "HTTP_CODE:" | cut -d: -f2)"
    resp="$(echo "$resp" | sed '/HTTP_CODE:/d')"

    if [[ "$code" == "429" ]]; then
      local wait
      wait="$(echo "$resp" | jq -r '.retry_after // 1')"
      echo "Rate limited; waiting ${wait}s..." >&2
      sleep "$wait"
      ((i++))
      continue
    fi

    echo "$resp"
    return 0
  done

  echo "Failed after $retries retries" >&2
  return 1
}
```

## Backlog DB property mapping

Mapping used by `pg-to-notion-sync.sh`:

| PG field | Notion property | Transform |
|----------|-----------------|-----------|
| `title` | `US Title` | title |
| `status` | `Status` | `map_status()` → Open / In Progress / Done / Backlog / Blocked / Cancelled / Pending |
| `priority` | `Priority` | `map_priority()` → Critical / High / Medium / Low |
| `type` | `Type` | `map_category()` → Technical / Platform / Business / Operations |
| `sprint` | `Sprint` | select (when configured) |
| `created_at` | `Created Date` | date |
| `updated_at` | `Last Updated` | date |

## Common pitfalls

- **U+0000 in JSONB metadata** can break `jq` when using `row_to_json`. Query columns individually or sanitize.
- **Title property name** is `US Title`, not `title` or `Name`.
- **Relation properties** cannot be set via simple select; use page IDs in the relation format if needed.
- **Empty `next_cursor`** with `has_more:true` is valid — keep paging until `has_more:false`.

## DB IDs

| DB | ID |
|----|----|
| Backlog | `34dc1829-53ff-814b-8257-d3a3bf351d44` |
| Auto-Heal | `364c1829-53ff-81c0-9dbd-ff2c907d1a6b` |
| Archive | `364c1829-53ff-818e-a783-ebafcb6a9880` |

## References

- Notion API docs: https://developers.notion.com/reference
- Skill entry point: `agent-skills/notion/SKILL.md`
