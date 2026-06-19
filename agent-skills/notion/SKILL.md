---
name: notion
description: AInchors Notion integration patterns — auth, DB IDs, API conventions, rate limits, and common operations for tickets, backlog, and Holocron.
---

# Notion skill — When to Load

Load this skill whenever you are:

- Syncing tickets or backlog data to Notion.
- Creating, updating, or querying Notion pages or databases.
- Working on Holocron (knowledge base) pages or blocks.
- Writing or editing a script that calls the Notion API.
- Validating that Notion auth and DB connectivity are healthy.

If you're about to invoke any script whose primary job involves Notion, load this skill first, then load any secondary domain skills (e.g., `pg-sprint-backlog`, `changelog`).

## Quick Reference

| Item | Value |
|------|-------|
| API base | `https://api.notion.com/v1` |
| API version | `2022-06-28` |
| Auth file | `~/.config/notion/api_key` |
| Rate limit rule | ~3 requests per second; sleep 350ms between calls |
| Retry policy | On HTTP 429, wait `Retry-After` seconds then retry up to 3 times |

### Canonical DB IDs

| DB | ID |
|----|----|
| Backlog (DB A) | `34dc1829-53ff-814b-8257-d3a3bf351d44` |
| Auto-Heal (DB B) | `364c1829-53ff-81c0-9dbd-ff2c907d1a6b` |
| Archive (DB C) | `364c1829-53ff-818e-a783-ebafcb6a9880` |

These IDs are also recorded in `TOOLS.md`. The skill references them here for convenience, but `TOOLS.md` is the SSOT for environment-specific values.

## Auth

Read the API key from the canonical file:

```bash
NOTION_KEY="$(cat ~/.config/notion/api_key 2>/dev/null || echo "")"
[[ -z "$NOTION_KEY" ]] && { echo "Notion API key missing"; exit 1; }
```

Never commit the key. Never pass it as a command-line argument in crons or logs.

## Request headers

Every request must include:

```bash
-H "Authorization: Bearer $NOTION_KEY" \
-H "Notion-Version: 2022-06-28" \
-H "Content-Type: application/json"
```

## Common operations

### 1. Validate auth and list DBs

```bash
curl -s "https://api.notion.com/v1/users/me" \
  -H "Authorization: Bearer $NOTION_KEY" \
  -H "Notion-Version: 2022-06-28"
```

### 2. Query a database

```bash
DB_ID="34dc1829-53ff-814b-8257-d3a3bf351d44"
curl -s -X POST "https://api.notion.com/v1/databases/$DB_ID/query" \
  -H "Authorization: Bearer $NOTION_KEY" \
  -H "Notion-Version: 2022-06-28" \
  -H "Content-Type: application/json" \
  -d '{"page_size": 100}'
```

### 3. Create a page in a database

```bash
DB_ID="34dc1829-53ff-814b-8257-d3a3bf351d44"
curl -s -X POST "https://api.notion.com/v1/pages" \
  -H "Authorization: Bearer $NOTION_KEY" \
  -H "Notion-Version: 2022-06-28" \
  -H "Content-Type: application/json" \
  -d "$(jq -n --arg db "$DB_ID" --arg title "Example Title" '{
    parent: {database_id: $db},
    properties: {
      "US Title": {title: [{text: {content: $title}}]}
    }
  }')"
```

### 4. Update a page

```bash
PAGE_ID="384c1829-53ff-81be-b722-cfb5f9172801"
curl -s -X PATCH "https://api.notion.com/v1/pages/$PAGE_ID" \
  -H "Authorization: Bearer $NOTION_KEY" \
  -H "Notion-Version: 2022-06-28" \
  -H "Content-Type: application/json" \
  -d '{"properties": {"Status": {"select": {"name": "Done"}}}}'
```

### 5. Archive a page

```bash
PAGE_ID="384c1829-53ff-81be-b722-cfb5f9172801"
curl -s -X PATCH "https://api.notion.com/v1/pages/$PAGE_ID" \
  -H "Authorization: Bearer $NOTION_KEY" \
  -H "Notion-Version: 2022-06-28" \
  -H "Content-Type: application/json" \
  -d '{"archived": true}'
```

## Rate limiting and retries

AInchors scripts use a simple guard:

```bash
rate_limit() { sleep 0.35; }
```

If you receive HTTP 429, respect the `Retry-After` header and retry up to 3 times before failing.

## Error handling

- **No key file → exit 1 immediately.**
- **HTTP 401 → fail loudly; do not swallow.**
- **HTTP 429 → retry with backoff.**
- **HTTP 5xx → retry once, then fail.**
- **Missing DB or page → log and continue if batch; fail if single-item critical path.**

## Backlog DB schema notes

The Backlog DB uses these property names:

| Field | Notion property | Notes |
|-------|-----------------|-------|
| Title | `US Title` | title property |
| Status | `Status` | select |
| Priority | `Priority` | select |
| Type | `Type` | select |
| Sprint | `Sprint` | relation or select depending on DB config |

Always inspect the live DB schema if property names change. Do not hardcode schema assumptions in long-lived scripts without a re-sync check.

## Scripts in this skill package

- `agent-skills/notion/scripts/notion-env-check.sh` — validate auth + DB reachability.

## Holocron guidance

Holocron pages are standard Notion pages. Use the page create/update patterns above. For structured knowledge, prefer databases over freeform pages so Holocron content remains queryable.

## See also

- `agent-skills/notion/references/notion-api-patterns.md` — detailed curl/JSON examples
- `TOOLS.md` — canonical DB IDs and environment notes
