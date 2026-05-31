#!/usr/bin/env bash
#
# migrate-to-pnpm.sh — find every npm project under a directory and migrate it to pnpm.
#
# For each package-lock.json (outside node_modules) it runs:
#     pnpm import && rm -rf node_modules package-lock.json && pnpm install
#
# Usage:
#   ./migrate-to-pnpm.sh [DIR] [--dry-run]
#
#   DIR         Root folder to search (default: current directory)
#   --dry-run   List the projects that would be migrated, but change nothing
#
set -uo pipefail

ROOT="."
DRY_RUN=0

for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    -h|--help)
      grep '^#' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *) ROOT="$arg" ;;
  esac
done

if [ ! -d "$ROOT" ]; then
  echo "error: '$ROOT' is not a directory" >&2
  exit 1
fi

if ! command -v pnpm >/dev/null 2>&1; then
  echo "error: pnpm is not installed. Install it first, e.g.: npm install -g pnpm" >&2
  exit 1
fi

echo "Searching for npm projects under: $ROOT"
[ "$DRY_RUN" -eq 1 ] && echo "(dry run — no changes will be made)"
echo

succeeded=0
failed=0
skipped=0
failed_dirs=()

# -print0 / read -d '' keeps paths with spaces intact.
while IFS= read -r -d '' lockfile; do
  dir=$(dirname "$lockfile")

  if [ "$DRY_RUN" -eq 1 ]; then
    echo "would migrate: $dir"
    succeeded=$((succeeded + 1))
    continue
  fi

  echo "==> Migrating $dir"
  if (
    cd "$dir" || exit 1
    pnpm import && rm -rf node_modules package-lock.json && pnpm install
  ); then
    echo "    ok: $dir"
    succeeded=$((succeeded + 1))
  else
    echo "    FAILED: $dir" >&2
    failed=$((failed + 1))
    failed_dirs+=("$dir")
  fi
  echo
done < <(find "$ROOT" -name package-lock.json -not -path '*/node_modules/*' -print0)

echo "----------------------------------------"
if [ "$DRY_RUN" -eq 1 ]; then
  echo "Dry run complete. $succeeded project(s) would be migrated."
else
  echo "Done. Migrated: $succeeded   Failed: $failed"
  if [ "$failed" -gt 0 ]; then
    echo "Failed projects:"
    for d in "${failed_dirs[@]}"; do
      echo "  - $d"
    done
    exit 1
  fi
fi
