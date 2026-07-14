# PostgreSQL OC2A Recovery SOP

## Environment
- Host: OC2A (Mac mini M4 Pro 48GB)
- Homebrew prefix: `/Users/ainchorsoc2a/homebrew`
- Brew command: `/Users/ainchorsoc2a/homebrew/bin/brew`
- Service: `postgresql@16`
- Socket path: `/tmp/.s.PGSQL.5432`
- Last updated: 2026-07-14 AEST

## Check status
pg_isready -h localhost -p 5432

## Start
/Users/ainchorsoc2a/homebrew/bin/brew services start postgresql@16

## Stop / rollback
/Users/ainchorsoc2a/homebrew/bin/brew services stop postgresql@16

## Common failure
Service did not auto-start after reboot until CHG-1784 configured `brew services start`.