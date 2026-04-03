# Architectural Analysis: dotfiles

## Stack & Size

| Attribute | Value |
|-----------|-------|
| Primary languages | Bash/Zsh, Go, Lua, TOML/JSON |
| Frameworks | GNU Stow, Bubbletea (Go TUI), LazyVim (Neovim), Oh My Zsh |
| Source files | ~47 (excluding submodules and generated lockfiles) |
| Git commits | 140 |
| Top-level packages | 12 (brew, claude, ghostty, kitty, launchd, mise, nvim, scripts, tmux, wt, zsh + root scripts) |
| CLI tools available | rubocop, brakeman (not relevant here); no scc, jscpd, or ast-grep |

## What's Working Well

- **Clean Stow package layout.** Each top-level directory maps to a single concern and mirrors `$HOME` correctly. A new developer can read the directory tree and understand the system.
- **Cross-platform installer.** `install.sh` is well-structured with logging, pre-flight checks, verification steps, and proper `set -euo pipefail` error handling. It handles macOS and multiple Linux distros.
- **Dotfiles auto-sync.** The launchd + `dotfiles-sync.sh` pattern is simple and reliable: fetch, compare, fast-forward pull, re-link. Safe failure mode with `--ff-only`.
- **Go dashboard architecture.** `wt/dashboard/` follows idiomatic Go layout with `cmd/`, `internal/`, and clear package boundaries. The Bubbletea model/update/view pattern is applied correctly.
- **Thread-safe state reader.** `state.Reader` uses `sync.RWMutex` properly, and the JSON state file approach is simple and debuggable.
- **Conditional tool activation.** `.zshrc` guards every tool activation (`mise`, `fzf`, `scmpuff`) with `command -v` checks, so the shell starts cleanly even when tools are missing.
- **Comprehensive CLAUDE.md.** The repo CLAUDE.md thoroughly documents architecture, commands, known issues, and the auto-sync system. This is a strong onboarding artifact.

## Top Findings (ranked by impact)

### 1. `link.sh` uses `--adopt` flag which silently overwrites repo files

**Category**: Data Integrity & State | **Severity**: high
**Flagged by**: State & Data Flow, Error Handling, Structure & Conventions
**Evidence**: `link.sh:46` — `stow $folder -v --adopt`
**Impact**: `stow --adopt` moves existing files from `$HOME` *into* the repo, overwriting the dotfiles source. If a target file was modified outside the repo (e.g., a tool auto-edited `~/.config/kitty/kitty.conf`), running `link.sh link` silently replaces the repo's version. Combined with auto-sync, this could push unintended changes upstream.
**Direction**: Replace `--adopt` with plain `stow $folder -v` (or `--restow`). If adoption is needed for initial setup, make it a separate `link.sh adopt` command with a warning.

### 2. Hardcoded absolute paths reduce portability

**Category**: Maintainability & Conventions | **Severity**: high
**Flagged by**: Coupling, Structure & Conventions, State & Data Flow
**Evidence**:
- `zsh/.zshrc:181` — `fpath=(/Users/lukedanielson/Workspace/wealthbox-sandbox/completions $fpath)`
- `launchd/Library/LaunchAgents/com.dotfiles.sync.plist` — hardcodes `/Users/lukedanielson/.dotfiles/` and `/Users/lukedanielson/Library/Logs/`
**Impact**: These break on any other machine, other macOS user, or if directories are reorganized. The launchd plist cannot be shared or used on a fresh install without manual edits.
**Direction**: For the plist, use `$HOME` expansion via a templating step in `install.sh` (sed or envsubst), or use `launchctl setenv`. For the zshrc fpath, use `$HOME` and a conditional existence check.

### 3. Duplicate and conflicting PATH modifications in `.zshrc`

**Category**: Code Health & Complexity | **Severity**: medium
**Flagged by**: Complexity & Churn, Duplication, State & Data Flow
**Evidence**:
- Line 2: `export PATH=$HOME/bin:$HOME/.local/bin:/usr/local/bin:$PATH`
- Line 107: `export PATH="$HOME/.claude/scripts:$HOME/.local/bin:$PATH"`
- `$HOME/.local/bin` appears in both exports
**Impact**: PATH grows with duplicate entries on every shell invocation (subshells inherit the parent PATH and prepend again). This can slow command resolution and cause confusion when debugging which binary is found first.
**Direction**: Consolidate all PATH additions into a single block at the top of `.zshrc`, deduplicating entries. Or use a helper function that only adds to PATH if not already present.

### 4. `.zshrc` is 75% boilerplate comments (90/182 lines are comments)

**Category**: Maintainability & Conventions | **Severity**: medium
**Flagged by**: Structure & Conventions, Complexity & Churn
**Evidence**: `zsh/.zshrc` — 90 comment lines, 34 blank lines, only 58 active lines. Most comments are the Oh My Zsh template defaults that were never uncommented.
**Impact**: The file is the 2nd most-churned file (21 changes) but signal is buried in noise. Every edit requires scrolling past irrelevant template comments. The commented-out `EDITOR` export means no editor is explicitly set.
**Direction**: Remove all Oh My Zsh template comments that aren't being used. Keep only comments that explain *why* something is configured a way. Set `EDITOR=nvim` explicitly since Neovim is a core part of the setup.

### 5. `link.sh` has unquoted variable expansions

**Category**: Reliability & Error Handling | **Severity**: medium
**Flagged by**: Error Handling, Structure & Conventions
**Evidence**:
- Line 42: `pushd $DOT_FILES` (unquoted)
- Line 46: `stow $folder -v --adopt` (unquoted)
- Line 53: `pushd $DOT_FILES` (unquoted)
**Impact**: If `$DOT_FILES` or `$folder` ever contains spaces (unlikely for dotfiles, but a correctness issue), the script breaks silently. More importantly, this signals inconsistency — `install.sh` quotes variables properly throughout but `link.sh` does not.
**Direction**: Quote all variable expansions: `pushd "$DOT_FILES"`, `stow "$folder" -v`. Also add `set -uo pipefail` to match `install.sh` conventions.

### 6. Go dashboard `model.go` is a 519-line monolith handling all concerns

**Category**: Architecture & Coupling | **Severity**: medium
**Flagged by**: Coupling, Complexity & Churn, Structure & Conventions
**Evidence**: `wt/dashboard/internal/ui/model.go` — 519 lines containing the Bubbletea model struct, all message types, key handling, polling logic, and all rendering functions. It imports every other internal package (6 imports from `internal/`).
**Impact**: This is a classic "god file" that will grow with every new dashboard feature. The View rendering (200+ lines of string building) is interleaved with polling logic and state management. Any change to the dashboard likely touches this file.
**Direction**: Split into `model.go` (struct + Update + Init), `keys.go` (key handling), `render.go` (View + render helpers), and `poll.go` (async polling commands). The message types could move to a `messages.go` file.

### 7. Discarded errors in Go dashboard

**Category**: Reliability & Error Handling | **Severity**: medium
**Flagged by**: Error Handling, State & Data Flow
**Evidence**:
- `model.go:91` — `_ = m.reader.Load()` (in loadState command)
- `model.go:110` — `_ = m.reader.Load()` (in tick handler)
- `cmd/wt-dash/main.go:36` — `_ = cmd.Run()`
**Impact**: If the state file becomes corrupted or unreadable, the dashboard silently shows stale data with no indication to the user. The discarded `cmd.Run()` error means the tmux switch-session can fail without feedback.
**Direction**: For Load errors in the UI, set an error field on the model and display a status indicator. For `cmd.Run()`, at minimum log the error or print to stderr after the Bubbletea program exits.

## Lower Priority

### Maintainability & Conventions
- **Go `sortedAgentNames` uses manual bubble sort** (`model.go:492-506`) instead of `sort.Strings()`. Functionally correct for small N but unnecessarily verbose.
- **`mise/README.md` references migration from asdf** — leftover documentation from a completed migration. Could be trimmed.
- **No `.editorconfig` or shell formatter** — shell scripts have inconsistent style (some use `[[`, some `[`; quoting varies between files).

### Architecture & Coupling
- **Homebrew PATH setup is duplicated** between `install.sh` (lines 89-94) and `.zshrc` (lines 110-117). Both handle Linux and macOS ARM64 cases. Drift between them is likely.
- **`dotfiles-sync.sh` re-runs `link.sh` on every pull**, including the `--adopt` flag, which compounds Finding #1.

### Data Integrity & State
- **Launchd plist PATH is minimal** (`/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin`) and does not include Homebrew paths. The sync script works because `git` is at `/usr/bin/git`, but `stow` (from Homebrew) may not be found if the sync detects changes and runs `link.sh`.
- **No lock file on `dotfiles-sync.sh`** — if a sync takes longer than 5 minutes (network issue), two syncs could overlap.

### Code Health
- **`kitty.conf` is 1,407 lines** — almost certainly the full default config with a few customizations. Kitty supports partial configs that only override defaults.

## Metrics Summary

| Metric | Value |
|--------|-------|
| Most churned file | `nvim/.config/nvim/lazy-lock.json` (29 changes) — expected, this is a lockfile |
| Most churned source file | `zsh/.zshrc` (21 changes) |
| Largest source file | `wt/dashboard/internal/ui/model.go` (519 lines) |
| Largest config file | `kitty/.config/kitty/kitty.conf` (1,407 lines) |
| Active lines in `.zshrc` | 58 out of 182 (32%) |
| Files with unquoted variables | `link.sh` (3 instances) |
| Discarded Go errors | 5 instances across 3 files |
| Hardcoded absolute paths | 3 locations (zshrc fpath, launchd plist x2) |
| Temporal coupling | `install.sh` + `.zshrc` change together in 6 commits |
