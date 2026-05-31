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
./migrate-to-pnpm.sh [DIR] [--dry-run] [--log FILE]
```

| Argument      | Description                                            |
| ------------- | ----------------------------------------------------- |
| `DIR`         | Root folder to search. Defaults to the current directory. |
| `--dry-run`   | List the projects that would be migrated, but change nothing. |
| `--log FILE`  | Write the run log to `FILE`. Defaults to `./migrate-to-pnpm-<timestamp>.log`. |
| `-h`, `--help`| Print usage help.                                     |

### Examples

```bash
# Preview every project that would be migrated under ~/Documents/project
./migrate-to-pnpm.sh ~/Documents/project --dry-run

# Migrate everything under ~/Documents/project
./migrate-to-pnpm.sh ~/Documents/project

# Migrate and write the log to a specific file
./migrate-to-pnpm.sh ~/Documents/project --log ~/pnpm-migration.log

# Search the current directory
./migrate-to-pnpm.sh
```

## Logging & results report

Every run is timestamped and streamed to **both the console and a log file** (`tee`).
The log file path is printed at the start and end of the run, so you can review it
later or share it. By default it's written to `./migrate-to-pnpm-<timestamp>.log`;
override it with `--log FILE`.

The run has two phases:

1. **Search** — logs each npm project as it's discovered (lockfiles inside
   `node_modules` are skipped), then prints the total count.
2. **Migrate** — logs each project as `[N/total]` with its outcome and how long it took.
   The full `pnpm import` / `pnpm install` output is captured in the log too.

It ends with a **results report** summarizing the whole run:

```
14:22:01  ==================== migrate-to-pnpm ====================
14:22:01  Root:     /Users/you/Documents/project
14:22:01  Mode:     migrate + reinstall
14:22:01  Log file: ./migrate-to-pnpm-20260601-142201.log
14:22:01  Started:  2026-06-01 14:22:01

14:22:01  Searching for package-lock.json (excluding node_modules)...
14:22:01    found: /Users/you/Documents/project/apps/web
14:22:01    found: /Users/you/Documents/project/tools/cli

14:22:01  Discovered 2 npm project(s).

14:22:01  [1/2] ==> Migrating /Users/you/Documents/project/apps/web
14:22:09  [1/2] ok (8s): /Users/you/Documents/project/apps/web
14:22:09  [2/2] ==> Migrating /Users/you/Documents/project/tools/cli
14:22:14  [2/2] ok (5s): /Users/you/Documents/project/tools/cli

14:22:14  ======================== RESULTS ========================
14:22:14  Root:            /Users/you/Documents/project
14:22:14  Started:         2026-06-01 14:22:01
14:22:14  Finished:        2026-06-01 14:22:14
14:22:14  Duration:        13s
14:22:14  Projects found:  2
14:22:14  Migrated (ok):   2
14:22:14  Failed:          0

14:22:14  Succeeded:
14:22:14    [ok]      /Users/you/Documents/project/apps/web
14:22:14    [ok]      /Users/you/Documents/project/tools/cli
14:22:14  =========================================================
14:22:14  Full log saved to: ./migrate-to-pnpm-20260601-142201.log
```

If any project fails, it is listed under a `Failed:` section in the report and the
script exits with status `1`. Other projects are unaffected — one failure does not
abort the whole run.

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

## Releasing

This tool is distributed through the Homebrew tap
[`tisohjung/homebrew-tap`](https://github.com/tisohjung/homebrew-tap), and the
tap's formula (`Formula/migrate-to-pnpm.rb`) is the single source of truth for
the published `url` + `sha256`.

Cutting a release is a single step — push a version tag:

```bash
git tag v1.2.0
git push origin v1.2.0
```

The [`update-homebrew-formula`](.github/workflows/update-homebrew-formula.yml)
GitHub Actions workflow then runs automatically and:

1. Downloads the release source tarball and computes its `sha256`.
2. Checks out the tap repo.
3. Updates `url` + `sha256` in the formula.
4. Commits and pushes to the tap — but only if something actually changed.

Users then pick up the new version with:

```bash
brew upgrade migrate-to-pnpm
```

### One-time setup

The workflow pushes to a **different** repository (the tap), which the default
`GITHUB_TOKEN` cannot do. It needs a fine-grained Personal Access Token:

- **Scope:** repository `tisohjung/homebrew-tap`, **Contents: Read and write**.
- Stored on this repo as the secret **`HOMEBREW_TAP_TOKEN`**
  (`gh secret set HOMEBREW_TAP_TOKEN --repo tisohjung/migrate-npm-to-pnpm`).

### Testing the workflow

Re-run it against an existing tag from the Actions tab, or via the CLI:

```bash
gh workflow run "Update Homebrew formula" \
  --repo tisohjung/migrate-npm-to-pnpm -f tag=v1.1.0
```

For an unchanged tag it reports *"Formula already up to date — nothing to
commit"* and makes no commit, which confirms the pipeline works without
publishing anything.
