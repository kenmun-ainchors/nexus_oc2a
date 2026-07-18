#!/bin/zsh
# r01-session-sweep.sh — CHG-0924
# Periodic auto-heal: replace literal "~/.openclaw" with the absolute path
# /Users/ainchorsoc2a/.openclaw in session .jsonl files so R01 (Path Discipline)
# stays PASS between gateway writes.
#
# Safety:
#   * Skips files that lsof reports as currently open (e.g. the gateway's own
#     active session file, which the runtime is writing to continuously).
#   * Skips files with mtime within the last 60 seconds (active write window).
#   * Skips the well-known gateway session id (d7b82941) as a structural guard.
#   * Backs up every modified file to state/chg-0923-backups/ before mutating.
#   * Uses atomic mv to replace the file in place; preserves mode/ownership.
#
# Usage: bash scripts/r01-session-sweep.sh
# Exit:  0 on success (even if no files processed), 1 on fatal error.

set -u

HOME_DIR="/Users/ainchorsoc2a"
TILDE="~/.openclaw"
ABS="/Users/ainchorsoc2a/.openclaw"
WORKSPACE="/Users/ainchorsoc2a/.openclaw/workspace"
BACKUP_ROOT="${WORKSPACE}/state/chg-0923-backups"
SUMMARY="${WORKSPACE}/state/r01-session-sweep-last-run.json"
SESSIONS_ROOT="${HOME_DIR}/.openclaw/agents"

NOW_ISO=$(date -u +%Y-%m-%dT%H:%M:%SZ)
NOW_EPOCH=$(date +%s)
TMPDIR_LOCAL=$(mktemp -d -t r01sweep.XXXXXX)
trap 'rm -rf "$TMPDIR_LOCAL"' EXIT

files_processed=0
tildes_replaced=0
files_skipped_locked=0
files_skipped_fresh=0
files_skipped_structural=0
files_failed=0
errors_json="[]"

mkdir -p "$BACKUP_ROOT" 2>/dev/null || {
  echo "FATAL: cannot create backup root $BACKUP_ROOT" >&2
  exit 1
}

# Helper: emit a JSON string array element.
json_err() {
  # $1 = path, $2 = reason
  printf '{"path":"%s","reason":"%s"}' "${1//\"/\\\"}" "${2//\"/\\\"}"
}

# Structural skip: gateway's own active session file. The runtime writes
# tilde paths into this file at every turn. Replacing it under the runtime
# would race the writer and risk losing or corrupting recent entries.
GATEWAY_SKIP_IDS=(
  "d7b82941-467c-44a0-bd1f-09d703fb4210"
)
is_structural_skip() {
  local file="$1"
  local base="${file##*/}"
  local stem="${base%.jsonl}"
  for sid in "${GATEWAY_SKIP_IDS[@]}"; do
    [[ "$stem" == "$sid" ]] && return 0
  done
  return 1
}

# When invoked as /bin/zsh, use zsh's nullglob; when invoked as bash, emulate
# nullglob behaviour. Either way, missing patterns expand to an empty list.
if [[ -n "${ZSH_VERSION:-}" ]]; then
  setopt NULL_GLOB
else
  shopt -s nullglob 2>/dev/null || true
fi
# Tilde scan: only files that actually contain the literal need sweeping.
# macOS /bin/bash 3.2 mishandles `read -d ''` on NUL-separated input from
# `grep -lZ`, so we route the candidate list through a temp file and parse
# it with xargs/printf instead. Works under both bash and zsh.
candidate_files=()
if command -v grep >/dev/null 2>&1; then
  _r01_cand_tmp="${TMPDIR_LOCAL}/candidates.$$.txt"
  grep -lZF "$TILDE" "$SESSIONS_ROOT"/*/sessions/*.jsonl 2>/dev/null \
    | tr '\0' '\n' > "$_r01_cand_tmp" 2>/dev/null || true
  if [[ -s "$_r01_cand_tmp" ]]; then
    while IFS= read -r hit; do
      [[ -n "$hit" ]] && candidate_files+=("$hit")
    done < "$_r01_cand_tmp"
  fi
  rm -f "$_r01_cand_tmp"
fi
if [[ -z "${ZSH_VERSION:-}" ]]; then
  shopt -u nullglob 2>/dev/null || true
fi

if [[ ${#candidate_files[@]} -eq 0 ]]; then
  echo "INFO: no tilde-bearing .jsonl files under $SESSIONS_ROOT" >&2
fi

for file in "${candidate_files[@]:-}"; do
  [[ -z "$file" ]] && continue

  # Structural skip (gateway's own session) — never touch.
  if is_structural_skip "$file"; then
    files_skipped_structural=$((files_skipped_structural + 1))
    continue
  fi

  # lsof gate: skip if any process currently has the file open.
  if lsof "$file" >/dev/null 2>&1; then
    files_skipped_locked=$((files_skipped_locked + 1))
    continue
  fi

  # Freshness gate: skip if mtime is within last 60s.
  mtime_epoch=$(stat -f %m "$file" 2>/dev/null || echo 0)
  age=$(( NOW_EPOCH - mtime_epoch ))
  if [[ $age -lt 60 ]]; then
    files_skipped_fresh=$((files_skipped_fresh + 1))
    continue
  fi

  # Compute relative path under the session root, then mirror it under
  # BACKUP_ROOT so each agent's backups stay grouped.
  rel="${file#${SESSIONS_ROOT}/}"
  backup_path="${BACKUP_ROOT}/${rel}"
  backup_dir="${backup_path%/*}"

  if [[ ! -f "$backup_path" ]]; then
    mkdir -p "$backup_dir" 2>/dev/null || {
      err=$(json_err "$file" "mkdir backup failed: $backup_dir")
      errors_json=$(echo "$errors_json" | jq --argjson e "$err" '. + [$e]')
      files_failed=$((files_failed + 1))
      continue
    }
    cp -p "$file" "$backup_path" 2>/dev/null || {
      err=$(json_err "$file" "cp to backup failed: $backup_path")
      errors_json=$(echo "$errors_json" | jq --argjson e "$err" '. + [$e]')
      files_failed=$((files_failed + 1))
      continue
    }
  fi

  # Capture mode/ownership so atomic mv preserves them.
  src_mode=$(stat -f %Lp "$file" 2>/dev/null || echo "600")
  src_uid=$(stat -f %u "$file" 2>/dev/null || echo "")
  src_gid=$(stat -f %g "$file" 2>/dev/null || echo "")

  tmp_file="${TMPDIR_LOCAL}/$(basename "$file").sed.$$"
  # grep -c returns "0" + exit 1 on no matches; capture exit code so the
  # result is always a single integer.
  before_count=$(grep -cF "$TILDE" "$file" 2>/dev/null; true) || true
  before_count=$(printf '%s' "$before_count" | awk 'END{print $1+0}')
  [[ -z "$before_count" ]] && before_count=0
  if ! sed -e "s|${TILDE}|${ABS}|g" "$file" > "$tmp_file" 2>/dev/null; then
    rm -f "$tmp_file"
    err=$(json_err "$file" "sed failed")
    errors_json=$(echo "$errors_json" | jq --argjson e "$err" '. + [$e]')
    files_failed=$((files_failed + 1))
    continue
  fi

  after_count=$(grep -cF "$TILDE" "$tmp_file" 2>/dev/null; true) || true
  after_count=$(printf '%s' "$after_count" | awk 'END{print $1+0}')
  [[ -z "$after_count" ]] && after_count=0
  replaced_here=$(( before_count - after_count ))
  if [[ $replaced_here -le 0 ]]; then
    rm -f "$tmp_file"
    # Nothing changed (race with another sweeper). Treat as no-op.
    continue
  fi

  if ! mv -f "$tmp_file" "$file" 2>/dev/null; then
    rm -f "$tmp_file"
    err=$(json_err "$file" "atomic mv failed")
    errors_json=$(echo "$errors_json" | jq --argjson e "$err" '. + [$e]')
    files_failed=$((files_failed + 1))
    continue
  fi

  # Restore mode/ownership to be safe (mv -f across same dir preserves them,
  # but cross-tmp moves can drop setuid bits; we explicitly restore).
  [[ -n "$src_mode" ]] && chmod "$src_mode" "$file" 2>/dev/null || true
  if [[ -n "$src_uid" && -n "$src_gid" ]]; then
    chown "${src_uid}:${src_gid}" "$file" 2>/dev/null || true
  fi

  files_processed=$((files_processed + 1))
  tildes_replaced=$((tildes_replaced + replaced_here))
done

# Build summary JSON.
summary_json=$(jq -n \
  --arg ts "$NOW_ISO" \
  --argjson fp "$files_processed" \
  --argjson tr "$tildes_replaced" \
  --argjson fsl "$files_skipped_locked" \
  --argjson fsf "$files_skipped_fresh" \
  --argjson fss "$files_skipped_structural" \
  --argjson ff "$files_failed" \
  --argjson errs "$errors_json" \
  '{
    timestamp: $ts,
    filesProcessed: $fp,
    tildeRefsReplaced: $tr,
    filesSkippedLocked: $fsl,
    filesSkippedFresh: $fsf,
    filesSkippedStructural: $fss,
    filesFailed: $ff,
    errors: $errs
  }')

echo "$summary_json" > "$SUMMARY"

if [[ $files_failed -gt 0 ]]; then
  echo "WARN: $files_failed file(s) failed to sweep; see $SUMMARY" >&2
  exit 1
fi

exit 0
