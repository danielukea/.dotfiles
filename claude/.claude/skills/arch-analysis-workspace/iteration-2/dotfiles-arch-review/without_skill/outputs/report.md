# Dotfiles Architectural Review

**Repository:** `~/.dotfiles`
**Date:** 2026-04-02
**Scope:** Full codebase analysis

## Codebase Profile

| Metric | Value |
|--------|-------|
| Stow packages | 11 (brew, claude, ghostty, kitty, launchd, mise, nvim, scripts, tmux, wt, zsh) |
| Total files | 142 |
| Lines of code | ~9,100 |
| Code duplication | 0.09% (2 clones found -- negligible) |
| Primary languages | Bash/Zsh (shell), Lua (nvim), Go (wt dashboard), Markdown (claude skills/docs) |

## Findings

### 1. BUG: `scripts/` package leaks file into home directory

**Severity: Medium**

The `scripts/` directory contains `dotfiles-sync.sh` and is treated as a Stow package by `link.sh` (which iterates over all `*/` directories). This causes `~/dotfiles-sync.sh` to be symlinked into the home directory:

```
/Users/lukedanielson/dotfiles-sync.sh -> .dotfiles/scripts/dotfiles-sync.sh
```

The CLAUDE.md says scripts is "not stowed, used in-place" but there is no mechanism to exclude it. The launchd plist references it via its absolute path in the repo, so it does not need to be stowed.

**Fix:** Either:
- Add a `.stow-local-ignore` file to `scripts/` containing `*` (ignore everything), or
- Exclude `scripts/` from the `link.sh` loop by name, or
- Move `scripts/` contents under another package (e.g., `launchd/`) and remove the top-level directory

### 2. Hardcoded username in 4 locations

**Severity: Medium -- portability blocker**

The following files contain `/Users/lukedanielson` hardcoded:

| File | Occurrences |
|------|-------------|
| `launchd/.../com.dotfiles.sync.plist` | 3 (script path, stdout log, stderr log) |
| `zsh/.zshrc` | 1 (`fpath` for wealthbox-sandbox completions) |

The plist is the bigger problem: macOS LaunchAgents do not support `$HOME` or `~` expansion in plist values. Common solutions:
- Generate the plist from a template during `install.sh` (e.g., `sed "s|__HOME__|$HOME|g" sync.plist.template > sync.plist`)
- Use a wrapper script that the plist calls, letting the script resolve `$HOME`

The `.zshrc` hardcoded path is simpler to fix -- replace with `$HOME/Workspace/wealthbox-sandbox/completions`.

### 3. `link.sh` uses `--adopt` which silently overwrites repo files

**Severity: Medium -- data loss risk**

`link.sh` runs `stow $folder -v --adopt` for every package. The `--adopt` flag moves existing target files into the Stow package directory, replacing the repo's version. This means if a user has modified a config file locally (e.g., edited `~/.tmux.conf` outside the repo), running `link.sh link` will silently replace the repo's file with the local version.

This is especially risky because the auto-sync agent runs `link.sh link` every 5 minutes after pulling -- if a merge conflict left a file in a bad state, `--adopt` could propagate damage.

**Fix:** Remove `--adopt` and use `--restow` instead, or prompt before adopting. At minimum, do a `git diff --quiet` check after linking to catch accidental adoptions.

### 4. `.stow-local-ignore` at repo root only ignores `.gitmodules`

**Severity: Low**

The root `.stow-local-ignore` only contains `.gitmodules`. Since Stow is invoked per-package (not on the root), this file has no effect -- it would only matter if someone ran `stow .dotfiles` from the parent directory. It can be removed or repurposed.

Meanwhile, several directories should probably not be stowed but are:
- `scripts/` (see finding #1)
- Top-level files like `install.sh`, `link.sh`, `README.md`, `LICENSE`, `CLAUDE.md` are not stowed because they are files, not directories -- Stow only processes subdirectories. No issue here, just noting.

### 5. Auto-sync agent has no error notification and limited PATH

**Severity: Low**

The launchd plist sets a minimal PATH (`/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin`) which does not include Homebrew's install location (`/opt/homebrew/bin` on Apple Silicon). This means `git` is using the Xcode/system version rather than the Homebrew version, and `stow` may not be found at all on a fresh system.

Additionally:
- There is no failure notification (e.g., terminal-notifier, osascript alert) when sync fails
- The sync script uses `set -e` but errors just silently end up in the log file
- No log rotation -- `~/Library/Logs/dotfiles-sync.log` will grow indefinitely

### 6. `zsh/.zshrc` has accumulated config that belongs elsewhere

**Severity: Low -- maintainability**

The `.zshrc` file (182 lines) mixes several concerns:
- Oh My Zsh boilerplate with commented-out defaults (lines 1-101)
- Tool activation: Homebrew, mise, fzf, scmpuff (lines 107-134)
- Wealthbox aliases sourcing (line 136)
- Secrets sourcing (line 139)
- AWS profile management (~30 lines, 142-174)
- SSH aliases (line 178)
- Sandbox completions with hardcoded path (lines 180-182)

The AWS profile block is substantial and could be extracted to its own sourced file (e.g., `~/.aws_aliases.zsh`). The commented-out Oh My Zsh defaults (about 60 lines) provide no value and could be removed.

### 7. Two terminal emulator configs present (kitty + ghostty)

**Severity: Informational**

Both `kitty/` (68K, including a 50K `kitty.conf`) and `ghostty/` (28K) packages exist. The git history shows ghostty was added more recently with a custom theme. If ghostty is now the primary terminal, the kitty package is dead weight.

The kitty package also has its own README.md inside, which the `.stow-local-ignore` excludes from being symlinked -- a good practice that other packages (like `wt/`) also use.

### 8. `wt/` package mixes a Go project with stowed binaries

**Severity: Low -- structural oddity**

The `wt/` package contains:
- `bin/wt` -- a 28K Bash script that gets stowed to `~/bin/wt`
- `bin/_wt_help`, `bin/_wt_state` -- helper scripts also stowed to `~/bin/`
- `dashboard/` -- a full Go project (go.mod, cmd/, internal/) excluded via `.stow-local-ignore`

The Go dashboard source living inside a Stow package is unconventional. The dashboard binary presumably needs to be compiled and placed somewhere on PATH, but the build process is not integrated into `install.sh`. Consider:
- Moving the Go source to a separate repository or a top-level `src/` directory
- Adding a build step to `install.sh` that compiles `wt-dash` and places it in `~/bin/` or `~/.local/bin/`

### 9. No automated testing or validation

**Severity: Low**

There is no CI, no smoke test, and no validation script. For a dotfiles repo that auto-syncs every 5 minutes and can affect the entire shell environment, a basic validation step would be valuable:
- A `test.sh` that verifies stow can link all packages without conflicts
- A check that no hardcoded paths exist (grep for absolute home paths)
- Optionally, a GitHub Actions workflow that runs `stow -n` (dry run) on push

### 10. Mise config has duplicate `neovim` entry

**Severity: Informational**

`mise/.config/mise/config.toml` lists `neovim = "latest"` but neovim is already installed via Homebrew in the Brewfile. This means neovim is managed by both mise and Homebrew. Having two version managers for the same tool can cause PATH conflicts and confusion about which version is active. Pick one manager for neovim.

## Prioritized Recommendations

| Priority | Finding | Effort |
|----------|---------|--------|
| 1 | Fix `scripts/` stow leak (finding #1) | 5 min |
| 2 | Fix `.zshrc` hardcoded path (finding #2, partial) | 2 min |
| 3 | Remove `--adopt` from `link.sh` or add safety check (finding #3) | 10 min |
| 4 | Template the launchd plist to remove hardcoded paths (finding #2) | 30 min |
| 5 | Add Homebrew to launchd PATH (finding #5) | 5 min |
| 6 | Clean up `.zshrc` commented boilerplate (finding #6) | 15 min |
| 7 | Decide on kitty vs ghostty, remove unused (finding #7) | 5 min |
| 8 | Remove duplicate neovim from mise or Brewfile (finding #10) | 2 min |

## Summary

The dotfiles repo is well-organized with a clean Stow-based architecture and good separation of concerns across packages. The most impactful issues are the `scripts/` stow leak (a concrete bug creating an unwanted symlink in `$HOME`), the `--adopt` flag silently overwriting repo files on every sync, and hardcoded paths that prevent portability. These are all quick fixes. The rest are maintenance and cleanup items.
