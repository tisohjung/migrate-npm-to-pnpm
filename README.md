# migrate-to-pnpm

A small Bash script that recursively finds every npm project under a directory and migrates each one to [pnpm](https://pnpm.io/).

## Why migrate to pnpm?

[pnpm](https://pnpm.io/) is a drop-in alternative to npm that's faster and far more disk-efficient. Migrating is worthwhile because:

- **Saves disk space.** pnpm stores a single copy of each package version in a global content-addressable store and hard-links it into each project's `node_modules`. If you have dozens of projects that all depend on React or TypeScript, they share one copy on disk instead of duplicating it everywhere.
- **Faster installs.** Linking from the global store is much quicker than re-downloading and copying packages, especially on repeat installs across many projects.
- **Stricter, safer dependency resolution.** pnpm's non-flat `node_modules` prevents "phantom dependencies" — code accidentally importing packages it never declared — so your projects are more correct and reproducible.
- **Better for monorepos.** First-class workspace support makes managing many packages simpler.

### Why this script specifically?

Migrating one project by hand is easy; migrating **all of them** is the tedious part. If you have years of side projects, client work, and experiments scattered across your drive, doing each one manually is error-prone and boring. This script:

- **Automates the whole sweep** — point it at a folder and it finds and converts every npm project underneath, no matter how deeply nested.
- **Recovers disk space in bulk** — the more projects you convert at once, the more deduplication pays off across the shared store.
- **Is safe to preview** — `--dry-run` lets you see exactly what will change before committing, and a failure in one project never aborts the rest.

## What it does

For every `package-lock.json` it finds (outside `node_modules`), it runs the following in that project's directory:

```bash
pnpm import && rm -rf node_modules package-lock.json && pnpm install
```

- `pnpm import` — generates a `pnpm-lock.yaml` from the existing `package-lock.json`, preserving resolved versions.
- `rm -rf node_modules package-lock.json` — removes the old npm artifacts.
- `pnpm install` — installs dependencies with pnpm.

Only projects that have a `package-lock.json` are touched, so yarn and existing pnpm projects are skipped automatically.

## Requirements

- Bash
- [pnpm](https://pnpm.io/installation) installed and on your `PATH` (e.g. `npm install -g pnpm`)

## Usage

```bash
./migrate-to-pnpm.sh [DIR] [--dry-run]
```

| Argument    | Description                                            |
| ----------- | ------------------------------------------------------ |
| `DIR`       | Root folder to search. Defaults to the current directory. |
| `--dry-run` | List the projects that would be migrated, but change nothing. |
| `-h`, `--help` | Print usage help.                                   |

### Examples

```bash
# Preview every project that would be migrated under ~/Documents/project
./migrate-to-pnpm.sh ~/Documents/project --dry-run

# Migrate everything under ~/Documents/project
./migrate-to-pnpm.sh ~/Documents/project

# Search the current directory
./migrate-to-pnpm.sh
```

## Output

The script prints progress per project and ends with a summary:

```
==> Migrating ./apps/web
    ok: ./apps/web

----------------------------------------
Done. Migrated: 3   Failed: 0
```

If any project fails, it is listed at the end and the script exits with status `1`. Other projects are unaffected — one failure does not abort the whole run.

## Safety notes

- **`rm -rf node_modules package-lock.json` is irreversible.** The script deletes lockfiles across many repositories at once.
- **Run `--dry-run` first** to confirm the list of projects before making changes.
- **Commit your work beforehand.** Having each project under version control lets you review the new `pnpm-lock.yaml` and revert if needed.
- **Monorepos**: each nested `package-lock.json` is migrated independently. Most npm monorepos keep a single root lockfile, so this is usually fine — but check if you have an unusual layout.

## How it works

- Uses `find "$ROOT" -name package-lock.json -not -path '*/node_modules/*'` to locate npm projects.
- Uses `find -print0` with `read -d ''` so paths containing spaces are handled correctly.
- Runs each migration in a subshell so a failure in one project doesn't stop the others.
- Checks that the target directory exists and that `pnpm` is installed before doing anything.
