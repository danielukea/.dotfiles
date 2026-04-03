# Architectural Analysis: dotfiles

## Stack & Size

| Attribute | Value |
|-----------|-------|
| **Primary languages** | Bash (1,316 LOC), Go (818 LOC), Lua (572 LOC), Zsh (121 LOC), Shell (312 LOC) |
| **Framework** | GNU Stow for symlink management, LazyVim for Neovim, Bubbletea (Go TUI) for dashboard |
| **Source files** | 61 code files, 79 markdown files |
| **Total commits** | 140 (68 in last 6 months) |
| **Top complexity** | `wt/bin/wt` (complexity: 232), `wt/dashboard/internal/ui/model.go` (complexity: 102) |
| **Available CLI tools used** | scc, ast-grep (sg), jscpd |

## What's Working Well

- **Clear Stow-based package structure.** Each top-level directory maps to a home directory package. A new contributor can understand the system by reading directory names alone.
- **Atomic state management in `_wt_state`.** The JSON state file uses temp-file-then-mv for writes, preventing corruption. The API is clean and consistent (`state/read`, `state/write`, `state/add_*`, `state/remove_*`).
- **Well-factored Go dashboard.** The `wt/dashboard` has clean separation: `internal/` packages for agent, git, process, services, state, tmux, and ui. Each package has a single focused file. Import boundaries are respected.
- **Comprehensive error handling in `install.sh`.** Uses `set -euo pipefail`, structured logging, pre-flight checks, and graceful fallbacks. The verification step at the end confirms critical tools are installed.
- **Good tmux configuration.** Clean prefix remapping, vim-style navigation, sensible defaults for scroll history, escape time, and window numbering.
- **Launchd auto-sync.** The 5-minute sync with `--ff-only` is a safe, sensible approach that fails gracefully on conflicts.
- **Effective use of `mise` over asdf.** Centralized global tool config in a single TOML file with sensible version pins.

## Top Findings (ranked by impact)

### 1. `wt/bin/wt` is a 1,006-line monolith with complexity 232

**Category**: Code Health & Complexity  |  **Severity**: high
**Flagged by**: Complexity & Churn, Structure & Conventions, Coupling
**Evidence**: `scc` reports complexity 232 for `wt/bin/wt`. It contains 12 subcommands (`new`, `rm`, `ls`, `switch`, `shell`, `agent`, `agents`, `up`, `down`, `status`, `dash`, `scan`), helper functions, and the dispatch table all in one file. It was also modified 5 times in the last 6 months (4th highest churn file).
**Impact**: Every change to any `wt` subcommand risks affecting others. The file is hard to navigate and reason about. The `cmd_scan` function alone is 150+ lines with deeply nested loops.
**Direction**: Split into per-command files (e.g., `_wt_cmd_new`, `_wt_cmd_rm`, `_wt_cmd_scan`) sourced from the main `wt` script. The `_wt_state` and `_wt_help` files already demonstrate this pattern. The shared helpers (git helpers, format helpers, process helpers) could become `_wt_utils`.

### 2. Inconsistent error handling strictness across shell scripts

**Category**: Reliability & Error Handling  |  **Severity**: high
**Flagged by**: Error Handling & Resilience, Structure & Conventions
**Evidence**:
- `install.sh`: `set -euo pipefail` (strictest)
- `wt/bin/wt`: `set -euo pipefail` (strictest)
- `link.sh`: `set -e` only (no `pipefail`, no `nounset`)
- `scripts/dotfiles-sync.sh`: `set -e` only
- `zsh/.fzf_commands.zsh`: no error handling at all

The `dotfiles-sync.sh` script runs unattended via launchd. A piped command failure or unset variable would silently pass with only `set -e`.
**Impact**: `link.sh` uses `pushd`/`popd` and iterates over directories — if `stow` fails mid-loop with a pipe, `set -e` alone won't catch it. The sync script runs every 5 minutes and its failures could go unnoticed.
**Direction**: Standardize on `set -euo pipefail` for all bash scripts. Add error logging to `dotfiles-sync.sh` since it runs unattended.

### 3. Hardcoded paths and machine-specific values

**Category**: Maintainability & Conventions  |  **Severity**: medium
**Flagged by**: State & Data Flow, Structure & Conventions, Coupling
**Evidence**:
- `launchd/Library/LaunchAgents/com.dotfiles.sync.plist` line 8: hardcoded `/Users/lukedanielson/.dotfiles/scripts/dotfiles-sync.sh`
- `zsh/.zshrc` line 181: hardcoded `fpath=(/Users/lukedanielson/Workspace/wealthbox-sandbox/completions $fpath)`
- `wt/bin/wt` lines 18-19: hardcoded `crm-web` and `helium-ui` repo mappings in `repo_root()`
- `wt/bin/wt` line 739: hardcoded `crm-web` and `helium-ui` as default repos

**Impact**: The dotfiles won't work correctly on a different machine or username without manual edits. The launchd plist is the most critical — it will silently fail if the username changes.
**Direction**: Use `$HOME` expansion where possible. For the launchd plist (which doesn't support env vars in `Program`), generate it from a template in `install.sh`. For `wt`, make the repo list configurable via an env var or config file.

### 4. Duplicated logic in `wsh()` and `wrc()` aliases

**Category**: Maintainability & Conventions  |  **Severity**: medium
**Flagged by**: Duplication & Patterns
**Evidence**: `zsh/.wealthbox_aliases.zsh` — `wsh()` (lines 5-28) and `wrc()` (lines 40-62) contain nearly identical logic:
- Both walk up directories looking for a Gemfile
- Both check if they're in a sandbox directory with the same pattern
- Both fall back to `bin/docker/interactive.sh`
- The only difference is `wrc` appends `rails c` to the command

**Impact**: Any change to project detection logic needs to be made in both places. If a new project type is added, it's easy to update one and miss the other.
**Direction**: Extract a shared `_wb_project_exec()` helper that handles project detection and dispatch, then have `wsh` and `wrc` call it with different arguments.

### 5. `wt/dashboard/internal/ui/model.go` concentrates too many concerns

**Category**: Code Health & Complexity  |  **Severity**: medium
**Flagged by**: Complexity & Churn, Structure & Conventions, Coupling
**Evidence**: 519 lines, complexity 102. Contains: the Bubbletea model, all message types, the Update loop, key handling, three polling methods (`pollAgents`, `pollGitAsync`, `pollServicesAsync`), the entire View rendering (sidebar + detail panel + footer), and helper functions. `jscpd` found 2 duplication clones within this file (the `WorktreeLive` nil-check initialization pattern at lines 141-145/149-153, and the async polling pattern at lines 241-253/257-269).
**Impact**: Any UI change requires editing this single file. The polling logic, rendering logic, and key handling are all interleaved.
**Direction**: Extract rendering into a separate `render.go`, polling into `polling.go`, and keep `model.go` focused on the Update loop and model definition.

### 6. Launchd sync PATH is incomplete

**Category**: Reliability & Error Handling  |  **Severity**: medium
**Flagged by**: Error Handling & Resilience, State & Data Flow
**Evidence**: `launchd/Library/LaunchAgents/com.dotfiles.sync.plist` sets PATH to `/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin`. This does not include `/opt/homebrew/bin` (Apple Silicon Homebrew path) or `~/.local/bin` (where mise-installed tools live). The `dotfiles-sync.sh` script calls `git`, which works, but `link.sh` calls `stow` (installed via Homebrew) — and `stow` lives at `/opt/homebrew/bin/stow` on Apple Silicon.
**Impact**: On Apple Silicon Macs, the sync agent may fail to find `stow` when it tries to re-link after pulling changes. Since the sync runs unattended, this failure would be silent (logged to `~/Library/Logs/dotfiles-sync.log` but not alerted).
**Direction**: Add `/opt/homebrew/bin` to the PATH in the plist, or have `dotfiles-sync.sh` source the Homebrew shellenv before running.

## Lower Priority

### Maintainability & Conventions
- **`link.sh` uses `--adopt` flag with stow**, which overwrites repo files with local versions. This is risky — if a local config has diverged, the repo copy gets silently replaced. Consider using plain `stow` without `--adopt` and handling conflicts explicitly.
- **`fzf_commands.zsh` is minimal** (2 functions) and `cdf()` uses unquoted command substitution (`cd $(find ...)`). Should quote to handle spaces in directory names.
- **`mise/config.toml` has duplicate devcontainer entries**: both `"npm:@devcontainers/cli"` and `"npm:devcontainer"` are installed. These may be the same tool under different names.

### Architecture & Coupling
- **The `wt` CLI has a hardcoded dependency on Wealthbox project structure** (`bin/wealthbox up/down/status`). The `cmd_up`, `cmd_down`, `cmd_status` commands directly invoke `bin/wealthbox`, making the CLI not portable to non-Wealthbox projects. Consider making the service management commands configurable per-repo.

### Code Health
- **Nvim `noice.lua` is known to crash** (documented in CLAUDE.md). The plugin file still exists with `enabled = false` presumably — but this should be verified and the file potentially removed if the plugin is permanently disabled.
- **No tests exist for the `wt` CLI** or the Go dashboard. For a tool managing git worktrees and tmux sessions, even basic smoke tests would catch regressions.

### Data Integrity & State
- **The `_wt_state` file has no locking mechanism.** If two `wt` commands run simultaneously (e.g., two terminals), both could read state, modify it, and write back — with the last write winning. The atomic write (temp + mv) prevents corruption but not lost updates.

## Metrics Summary

| Metric | Value |
|--------|-------|
| **Total lines of code** | 3,159 (excluding markdown) |
| **Languages** | 6 (Bash, Go, Lua, Zsh, Shell, TOML) |
| **Highest complexity file** | `wt/bin/wt` — 232 (scc) |
| **Second highest** | `wt/dashboard/internal/ui/model.go` — 102 (scc) |
| **Top churned file** | `nvim/.config/nvim/lazy-lock.json` — 10 changes (auto-generated, expected) |
| **Top churned source file** | `claude/.claude/settings.json` — 9 changes |
| **jscpd clones found** | 3 (2 in Go dashboard, 1 in skill markdown) |
| **Shell scripts** | 7 files, mixed strictness levels |
| **Stow packages** | 9 (brew, claude, ghostty, kitty, launchd, mise, nvim, tmux, zsh) + 2 non-stow (scripts, wt) |
