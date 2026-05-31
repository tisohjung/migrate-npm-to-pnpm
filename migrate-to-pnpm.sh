#!/usr/bin/env bash
#
# migrate-to-pnpm.sh — find every npm project under a directory and migrate it to pnpm.
#
# For each package-lock.json (outside node_modules) it runs:
#     pnpm import && rm -rf node_modules package-lock.json && pnpm install
#
# Usage:
#   ./migrate-to-pnpm.sh [DIR] [--dry-run] [--log FILE]
#
#   DIR          Root folder to search (default: current directory)
#   --dry-run    List the projects that would be migrated, but change nothing
#   --log FILE   Write the run log to FILE (default: ./migrate-to-pnpm-<timestamp>.log)
#
set -uo pipefail

ROOT="."
DRY_RUN=0
LOG_FILE=""

# --- parse args ----------------------------------------------------------------
while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) DRY_RUN=1 ;;
    --log)
      shift
      LOG_FILE="${1:-}"
      [ -z "$LOG_FILE" ] && { echo "error: --log needs a file path" >&2; exit 1; }
      ;;
    -h|--help)
      grep '^#' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *) ROOT="$1" ;;
  esac
  shift
done

if [ -z "$LOG_FILE" ]; then
  LOG_FILE="./migrate-to-pnpm-$(date '+%Y%m%d-%H%M%S').log"
fi

# --- logging helpers -----------------------------------------------------------
# log writes a timestamped line to both the console and the log file.
log() {
  printf '%s  %s\n' "$(date '+%H:%M:%S')" "$*" | tee -a "$LOG_FILE"
}

# --- preflight -----------------------------------------------------------------
if [ ! -d "$ROOT" ]; then
  echo "error: '$ROOT' is not a directory" >&2
  exit 1
fi

if ! command -v pnpm >/dev/null 2>&1; then
  echo "error: pnpm is not installed. Install it first, e.g.: npm install -g pnpm" >&2
  exit 1
fi

# Resolve ROOT to an absolute path for clearer logs.
ROOT_ABS=$(cd "$ROOT" && pwd)

: > "$LOG_FILE"  # truncate/create the log file
START_TS=$(date '+%Y-%m-%d %H:%M:%S')
START_EPOCH=$(date '+%s')

log "==================== migrate-to-pnpm ===================="
log "Root:     $ROOT_ABS"
log "Mode:     $([ "$DRY_RUN" -eq 1 ] && echo 'DRY RUN (no changes)' || echo 'migrate + reinstall')"
log "Log file: $LOG_FILE"
log "Started:  $START_TS"
log ""

# --- search phase --------------------------------------------------------------
log "Searching for package-lock.json (excluding node_modules)..."

lockfiles=()
while IFS= read -r -d '' lf; do
  lockfiles+=("$lf")
  log "  found: $(dirname "$lf")"
done < <(find "$ROOT_ABS" -name package-lock.json -not -path '*/node_modules/*' -print0 2>/dev/null)

total=${#lockfiles[@]}
log ""
log "Discovered $total npm project(s)."
log ""

if [ "$total" -eq 0 ]; then
  log "Nothing to do. Exiting."
  exit 0
fi

# --- migrate phase -------------------------------------------------------------
succeeded=0
failed=0
ok_dirs=()
failed_dirs=()

i=0
for lf in "${lockfiles[@]}"; do
  i=$((i + 1))
  dir=$(dirname "$lf")

  if [ "$DRY_RUN" -eq 1 ]; then
    log "[$i/$total] would migrate: $dir"
    ok_dirs+=("$dir")
    succeeded=$((succeeded + 1))
    continue
  fi

  log "[$i/$total] ==> Migrating $dir"
  proj_start=$(date '+%s')
  # Run the migration; tee its output to the log. pipefail makes the pipeline
  # reflect the migration's exit status rather than tee's.
  if (
    cd "$dir" || exit 1
    pnpm import && rm -rf node_modules package-lock.json && pnpm install
  ) 2>&1 | tee -a "$LOG_FILE"; then
    dur=$(( $(date '+%s') - proj_start ))
    log "[$i/$total] ok (${dur}s): $dir"
    ok_dirs+=("$dir")
    succeeded=$((succeeded + 1))
  else
    dur=$(( $(date '+%s') - proj_start ))
    log "[$i/$total] FAILED (${dur}s): $dir"
    failed_dirs+=("$dir")
    failed=$((failed + 1))
  fi
  log ""
done

# --- results report ------------------------------------------------------------
END_TS=$(date '+%Y-%m-%d %H:%M:%S')
ELAPSED=$(( $(date '+%s') - START_EPOCH ))

log "======================== RESULTS ========================"
log "Root:            $ROOT_ABS"
log "Started:         $START_TS"
log "Finished:        $END_TS"
log "Duration:        ${ELAPSED}s"
log "Projects found:  $total"
if [ "$DRY_RUN" -eq 1 ]; then
  log "Would migrate:   $succeeded"
else
  log "Migrated (ok):   $succeeded"
  log "Failed:          $failed"
fi
log ""

if [ "${#ok_dirs[@]}" -gt 0 ]; then
  log "$([ "$DRY_RUN" -eq 1 ] && echo 'Would migrate:' || echo 'Succeeded:')"
  for d in "${ok_dirs[@]}"; do
    log "  [ok]      $d"
  done
fi

if [ "${#failed_dirs[@]}" -gt 0 ]; then
  log ""
  log "Failed:"
  for d in "${failed_dirs[@]}"; do
    log "  [FAILED]  $d"
  done
fi

log "========================================================="
log "Full log saved to: $LOG_FILE"

[ "$failed" -gt 0 ] && exit 1
exit 0
