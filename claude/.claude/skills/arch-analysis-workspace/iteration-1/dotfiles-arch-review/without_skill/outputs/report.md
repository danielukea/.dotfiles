# Dotfiles Architecture Review

**Repository:** `~/.dotfiles`
**Date:** 2026-04-02

---

## Executive Summary

This is a well-structured GNU Stow-based dotfiles repository with good separation of concerns across packages. The architecture is sound for its purpose. The findings below are ordered by impact, starting with issues that could cause real problems, followed by structural improvements that would reduce maintenance burden over time.

---

## Critical Issues

### 1. `stow --adopt` silently overwrites repo contents

**File:** `link.sh`, line 45

```bash
stow $folder -v --adopt
```

The `--adopt` flag moves existing files from the home directory *into* the stow package, overwriting the repo's version. This means if a tool modifies a config file in `~` between syncs (e.g., Neovim updating `lazy-lock.json`, or a GUI settings editor), running `link.sh link` will silently replace the repo's version with whatever is on disk. Combined with the auto-sync agent that calls `./link.sh link` every 5 minutes, this creates a window where local modifications can overwrite tracked files and then get committed/pushed.

**Recommendation:** Remove `--adopt` and use plain `stow $folder -v`. If a conflict exists, stow will error and tell you which file conflicts, which is the safer behavior. If you specifically want adopt behavior during initial setup, make it an explicit flag (`link.sh link --adopt`).

### 2. Launchd sync agent PATH is too narrow

**File:** `launchd/Library/LaunchAgents/com.dotfiles.sync.plist`, line 20

```xml
<string>/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin</string>
```

This PATH does not include `/opt/homebrew/bin` (Apple Silicon Homebrew) or `$HOME/.local/bin`. The sync script calls `git` (which works since `/usr/bin/git` exists as the Xcode shim) and `./link.sh link`, which in turn calls `stow`. If `stow` is only available via Homebrew at `/opt/homebrew/bin/stow`, the sync will silently fail when trying to re-link after a pull.

**Recommendation:** Add `/opt/homebrew/bin` to the launchd PATH environment variable.

### 3. Sync script has no error handling for dirty worktree

**File:** `scripts/dotfiles-sync.sh`

The script uses `git pull --ff-only` which will fail if there are uncommitted changes. However, `set -e` is enabled, so the script will exit silently on failure. There is no notification mechanism -- the only evidence is in the log file.

**Recommendation:** Add explicit handling: check `git status --porcelain` before pulling, and log a clear warning if the worktree is dirty. Consider sending a notification (e.g., via `osascript` or `terminal-notifier`) on failure so it doesn't go unnoticed.

---

## Structural Improvements

### 4. Hardcoded username in multiple locations

The username `lukedanielson` appears in:
- `launchd/Library/LaunchAgents/com.dotfiles.sync.plist` (absolute path to script)
- `zsh/.zshrc` line 181: `fpath=(/Users/lukedanielson/Workspace/wealthbox-sandbox/completions $fpath)`

The plist file is inherently tied to macOS and absolute paths are somewhat expected there, but the `.zshrc` hardcoded path will break on any other machine or if the username changes. More importantly, it references a project-specific path (`wealthbox-sandbox`) directly in the shell config rather than in the sourced `~/.wealthbox_aliases.zsh` where it logically belongs.

**Recommendation:** Move the `fpath` addition into `~/.wealthbox_aliases.zsh` and use `$HOME` instead of the absolute path.

### 5. `wt` is a 1,006-line bash script with a separate Go dashboard

**Files:** `wt/bin/wt` (bash), `wt/dashboard/` (Go/Bubbletea)

The `wt` tool is substantial: 1,006 lines of bash handling 11+ subcommands with state management, tmux integration, git worktree operations, and process lifecycle management. This is well past the complexity threshold where bash becomes a liability -- error handling is fragile, testing is difficult, and refactoring is risky. Meanwhile, the dashboard component is already written in Go.

**Recommendation:** This is a natural candidate for rewriting the CLI portion in Go alongside the dashboard. The Go binary could incorporate both the CLI and dashboard as subcommands of a single compiled tool, eliminating the bash/Go split. This would also make the tool distributable and testable.

### 6. Redundant terminal emulator configs (kitty + ghostty)

**Packages:** `kitty/`, `ghostty/`

Both terminal emulator configurations are stowed. The kitty config is dated (September 2025, last commit October 2025) while ghostty is actively maintained (March 2027 commits). The kitty config includes a 50KB `kitty.conf` and uses the Everforest theme, while ghostty uses a custom Warp Modern theme -- they are not in sync.

**Recommendation:** If kitty is no longer the primary terminal, consider archiving the kitty package (move to an `archive/` directory excluded from stow) rather than continuing to stow it. This avoids stowing stale config that could confuse tools or take precedence.

### 7. `.stow-local-ignore` at repo root only ignores `.gitmodules`

**File:** `.stow-local-ignore`

The root `.stow-local-ignore` contains only `.gitmodules`. However, stow is run per-package from within each directory, so this root-level file has no effect -- stow reads `.stow-local-ignore` from the package directory, not the repo root. The files that should not be stowed (like `install.sh`, `link.sh`, `CLAUDE.md`, `README.md`, `LICENSE`, `scripts/`) are not being stowed only because stow operates on subdirectories. This is fine architecturally but the root `.stow-local-ignore` is misleading.

**Recommendation:** Either remove the root `.stow-local-ignore` (it has no effect) or document its purpose if there is an edge case being handled.

### 8. `link.sh` stows ALL directories indiscriminately

**File:** `link.sh`, line 43

```bash
for folder in */; do
```

This iterates over every directory, including `scripts/` (which has its own `.stow-local-ignore` -- actually it does not; only `kitty/` and `wt/` have them). The `scripts/` directory does not mirror the home directory structure, so stowing it would create `~/dotfiles-sync.sh` in the home directory, which is unintended.

Currently `scripts/` contains only `dotfiles-sync.sh`, and stow might handle this gracefully if no conflicts exist, but it is an accident waiting to happen. The `wt/` package uses `.stow-local-ignore` to exclude its `dashboard/` source directory, which is the right pattern.

**Recommendation:** Either add a `.stow-local-ignore` to `scripts/` or, better, maintain an explicit list of stow packages in `link.sh` rather than globbing all directories. An explicit list is more predictable and self-documenting:

```bash
PACKAGES=(brew claude ghostty kitty launchd mise nvim tmux wt zsh)
```

### 9. zshrc PATH is set twice with partial overlap

**File:** `zsh/.zshrc`

Line 2: `export PATH=$HOME/bin:$HOME/.local/bin:/usr/local/bin:$PATH`
Line 107: `export PATH="$HOME/.claude/scripts:$HOME/.local/bin:$PATH"`

`$HOME/.local/bin` is added twice. `$HOME/bin` is added on line 2 but it is unclear if this directory exists or is used. The Claude scripts path is added separately later.

**Recommendation:** Consolidate PATH setup into a single block near the top of the file, after Homebrew initialization (since Homebrew setup modifies PATH):

```bash
# Homebrew setup first (adds its bin to PATH)
# ... brew shellenv eval ...

# Then add personal paths
export PATH="$HOME/.claude/scripts:$HOME/.local/bin:$HOME/bin:$PATH"
```

### 10. No shellcheck or validation in CI

The repository has multiple bash scripts (`install.sh`, `link.sh`, `dotfiles-sync.sh`, `wt/bin/wt`) but no linting or automated validation. Given the sync agent runs unattended every 5 minutes, a broken script could cause silent failures.

**Recommendation:** Add a GitHub Actions workflow that runs `shellcheck` on all `.sh` files and the `wt` bash script. This is low-effort and catches common issues like unquoted variables (several exist in `link.sh`: `pushd $DOT_FILES`, `stow $folder`).

---

## Minor Observations

- **`packages.apt` referenced in CLAUDE.md but missing from repo.** The CLAUDE.md documentation mentions `packages.apt` for Ubuntu/Debian, but this file does not exist in the repository. The `install.sh` script no longer references it either (it uses Homebrew on Linux too). The documentation is stale.

- **Oh My Zsh as a git submodule.** The submodule at `zsh/.oh-my-zsh` pulls the entire ohmyzsh repository. This works but makes `git clone` slow and adds substantial weight. Modern alternatives like just sourcing the parts you need, or switching to a lighter plugin manager, could improve clone time. This is a minor concern since the submodule is shallow-cloneable.

- **Neovim `lazy-lock.json` is tracked in git.** This is the LazyVim lockfile that changes frequently as plugins update. Combined with the `--adopt` issue (#1), this file is a frequent source of merge noise. Consider adding it to `.gitignore` if exact plugin version reproducibility is not critical.

- **`mise` config uses `"latest"` for most tools.** In `mise/.config/mise/config.toml`, tools like Go, Rust, Node, and Neovim are pinned to `"latest"`. This means `mise install` on two machines at different times will produce different versions. If reproducibility matters, pin specific versions.

---

## Summary of Recommendations by Priority

| Priority | Issue | Effort |
|----------|-------|--------|
| High | Remove `--adopt` from `link.sh` stow commands | 5 min |
| High | Add `/opt/homebrew/bin` to launchd agent PATH | 5 min |
| Medium | Add dirty-worktree check to sync script | 15 min |
| Medium | Move hardcoded fpath out of `.zshrc` | 5 min |
| Medium | Use explicit package list in `link.sh` | 10 min |
| Medium | Consolidate PATH setup in `.zshrc` | 10 min |
| Medium | Add shellcheck CI workflow | 30 min |
| Low | Archive unused kitty config | 10 min |
| Low | Update stale CLAUDE.md references | 10 min |
| Low | Consider rewriting `wt` CLI in Go | Days |
