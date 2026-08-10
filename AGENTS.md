# AGENTS.md

Canonical guidance for any coding agent working in this repository. This is the single
source — `CLAUDE.md` is a thin `@import` of this file and holds no content of its own.
Edit here.

## Repository Overview

A personal dotfiles repo managed with **GNU Stow**. Each top-level directory is a "package"
that mirrors `$HOME` and gets symlinked into place.

**Supported platforms:** macOS and Linux (apt, dnf, or pacman based).

## Commands

### Installation

```bash
./install.sh              # Full setup: installs packages, sets git hooks, unlinks + re-links
./link.sh link            # Symlink all dotfiles packages to ~
./link.sh unlink          # Remove all symlinks from ~
```

Homebrew-first on both platforms: everything installs via `brew bundle` with
`brew/Brewfile`. On Linux, `apt-get`/`dnf`/`pacman` is used only to install Homebrew's own
build dependencies first. **There is no `packages.apt`.**

`install.sh` installs no language runtimes — run `mise install` afterward.

### Adding New Configurations

1. Create a new directory at the repo root (e.g. `newapp/`)
2. Mirror the home directory structure inside (e.g. `newapp/.config/newapp/config.toml`)
3. Run `./link.sh link` to symlink

## Architecture

### Package Structure

Each directory is a Stow package that mirrors `$HOME`:

- `agents/` - Agent-agnostic config shared across Claude Code, Codex, Gemini CLI:
  `.agents/AGENTS.md` (canonical user-level guidance), `.agents/skills/`, `.agents/docs/`,
  `.agents/scripts/` (usage-logging helpers), `.agents/HEALTHCHECK.md`
- `brew/` - Brewfile for Homebrew dependencies
- `claude/` - Claude Code configuration (`.claude/` settings, commands) — skills live in `agents/`, not here
- `codex/` - Codex config (`.codex/` AGENTS.md, hooks.json, rules)
- `ghostty/` - Ghostty terminal config (`.config/ghostty/`)
- `git/` - Global git ignore (`.config/git/ignore`)
- `githooks/` - Secret-scanning pre-commit hook for this repo (see Secret Scanning)
- `kitty/` - Terminal emulator config (`.config/kitty/`)
- `launchd/` - macOS LaunchAgents for background tasks (`Library/LaunchAgents/`)
- `lazygit/` - lazygit config (`.config/lazygit/`, plus a hand-symlink on macOS)
- `mise/` - Tool version manager config (`.config/mise/`)
- `nvim/` - LazyVim-based Neovim config (`.config/nvim/`)
- `scripts/` - Automation scripts used by launchd (`dotfiles-sync.sh`)
- `tmux/` - Tmux config (`.tmux.conf`)
- `zsh/` - Zsh shell config (`.zshrc`, oh-my-zsh as submodule)

`brew/`, `githooks/`, and `scripts/` don't mirror a `$HOME` subdirectory, so stowing them
drops loose files into `$HOME` root: `~/Brewfile`, `~/pre-commit`, `~/dotfiles-sync.sh`.
Expected, if untidy — don't "fix" them by moving the originals.

### Stow behavior

`link.sh link` stows every top-level directory with `stow --adopt`. Two consequences:

- **`--adopt` overwrites tracked files.** If a real (non-symlink) file already sits at a
  target path, stow moves it *into this repo*, replacing the committed version. Check
  `git status` after linking — an unexpected diff is an adopted file; `git checkout --
  <path>` restores the repo's copy.
- **`link` alone leaves stale symlinks.** Links for files you deleted or renamed persist
  until `./link.sh unlink && ./link.sh link` (or `./install.sh`, which does both).

`.stow-local-ignore` excludes paths from stowing — the repo root ignores `.gitmodules`.
Paths containing spaces can't be stowed at all — `install.sh` hand-symlinks those
(currently just lazygit → `~/Library/Application Support/lazygit/config.yml`, macOS only).

### Claude Code Configuration

The `claude/` package contains:

- `.claude/CLAUDE.md` - Thin `@import` of `~/.agents/AGENTS.md` (canonical) plus Claude-only notes
- `.claude/settings.json` - Model, effort, theme, plugins, status line, permissions, and
  hooks (usage logging on `Skill`/`Agent`; `PLANNING.md` injected on `EnterPlanMode`)
- `.claude/commands/` - Slash commands (currently just `healthcheck`)
- `.claude/templates/` - Spec templates (currently empty)

`settings.json` points nine hooks at `~/.local/share/yax/hooks/status-reporter.sh`. `yax`
is **not** managed by this repo — it's a Go binary built from `~/Workspace/yax` and
installed to `~/.local/bin/yax`. On a machine without it, those hooks fail silently and
agent status reporting is simply absent.

Skills are NOT under `claude/` — they're dotfiles-canonical under `agents/.agents/skills/`
(agent-agnostic, shared with Codex/Gemini CLI), and `link.sh` auto-bridges them into
`~/.claude/skills/` since Claude Code only discovers skills there. Add/edit skills under
`agents/.agents/skills/<name>/`; run `./link.sh link` if a new one isn't showing up yet.
Full bridging mechanism: see "Maintenance" in [~/.agents/docs/SKILLS.md](~/.agents/docs/SKILLS.md).

The bridge only links when nothing already exists at `~/.claude/skills/<name>`, so a name
that also exists there as a real directory (e.g. a marketplace install) is skipped silently
and your version never loads. Keep names unique to this repo.

Custom subagents were retired in favor of composable skills; orchestration skills fan out
`general-purpose` subagents that `Skill`-load the relevant knowledge skill.

### Tool Management

Uses `mise` (not asdf) for runtime version management. Global tools are defined in
`mise/.config/mise/config.toml`.

### Tmux Keybindings

Prefix is `C-s` (not `C-b`). Vim-style pane navigation: `h/j/k/l`. Split with `|` and `-`.

### Auto-Sync

Dotfiles automatically sync from GitHub every 5 minutes via a macOS launchd agent. When
changes are detected, it pulls and re-runs `./link.sh link` to apply new symlinks.

**Components:**

- `launchd/Library/LaunchAgents/com.dotfiles.sync.plist` - Scheduler (runs every 5 min)
- `scripts/dotfiles-sync.sh` - Sync script (fetch, compare, pull, re-link)

**Commands:**

```bash
launchctl list | grep dotfiles       # Check if agent is running
launchctl start com.dotfiles.sync    # Manually trigger sync
tail -f ~/Library/Logs/dotfiles-sync.log  # View sync logs
```

**Notes:**

- Uses `git pull --ff-only` to avoid merge conflicts (fails safely if local uncommitted changes exist)
- Agent is loaded automatically by `./install.sh`
- Because it re-runs `link` (not `unlink && link`), a synced deletion leaves a stale symlink behind

## Secret Scanning

This repo is public. `install.sh` runs `git config core.hooksPath githooks`, activating
`githooks/pre-commit` → `gitleaks protect --staged` against `.gitleaks.toml`.

The hook **exits 0 silently if gitleaks isn't installed**, so `brew install gitleaks` is
what actually makes it a guard. Fix false positives by editing `.gitleaks.toml`, never by
bypassing the hook.

## Skills — read before authoring

Agent skills live in `agents/.agents/skills/` and stow to `~/.agents/skills/` — the
cross-tool universal standard, read natively by Codex and Gemini CLI, and bridged into
`~/.claude/skills/` for Claude Code (which scans only that path).

**Before creating or editing any skill, read
[`agents/.agents/docs/SKILLS.md`](agents/.agents/docs/SKILLS.md)** — it captures the
principles for what makes a skill valuable (teach durable knowledge, don't railroad
judgment tasks; separate knowledge skills from orchestration; put project-specific
conventions in that project's rules, not in a portable skill).

The actionable entry point for the *craft* of authoring is the `write-skill` skill (in
`agents/.agents/skills/write-skill/`); this section covers the repo mechanics it
deliberately leaves out.

Keep skills **dotfiles-canonical**: author them here, then run `./link.sh link`. A skill
name that also exists in `~/.agents/skills` as a real directory (e.g. from the marketplace)
breaks the stow re-link — make this repo the single source.

## Conventions

- After changing skills or other stowed files, run `./link.sh link`.
- Skill/agent usage is logged by a portable `PostToolUse` hook
  (`agents/.agents/scripts/agent-usage-logger.sh`) → `~/.claude/logs/*.jsonl`. Wired
  into Claude Code (`claude/.claude/settings.json`, matchers `Skill`/`Agent`) and Codex
  (`codex/.codex/hooks.json`, matchers `Bash`/`spawn_agent` — Codex's hook-facing tool
  names, which are NOT what the model calls them: Codex's shell tool is `exec_command`
  to the model but `Bash` to the hook, confirmed empirically 2026-07-09 after
  `exec_command` as a matcher silently never fired. Codex has no discrete "skill
  invoked" tool call, so its skill-usage entries are a heuristic — scanning `Bash`
  commands for a `skills/<name>/SKILL.md` path — tagged `detection:"inferred"` vs
  Claude's `"explicit"`). Both hooks are user-level only (`~/.claude/settings.json`,
  `~/.codex/hooks.json`) — never duplicate this into a project's own `.claude/` or
  `.codex/` config; both tools merge hooks across user/project/local scopes, so the
  user-level hook already fires everywhere. Quick view: `skill-usage-report.sh`
  (same directory). Prune decisions: the `skill-prune` skill.
- Commit or push only when asked. This repo commits directly to `main` (a background
  agent auto-syncs via `git pull --ff-only` every 5 minutes).

## Context file layout

Content lives in AGENTS.md at both levels; CLAUDE.md files never hold content.

| Scope | Canonical file | Delegating files |
|-------|---------------|------------------|
| User | `agents/.agents/AGENTS.md` → `~/.agents/AGENTS.md` | `~/.claude/CLAUDE.md` (`@import`), `~/.codex/AGENTS.md` (symlink) |
| This repo | `AGENTS.md` (this file) | `CLAUDE.md` (`@AGENTS.md`) |

| Tool | Stow package | Stows to |
|------|-------------|----------|
| All agents | `agents/` | `~/.agents/` |
| Claude Code | `claude/` | `~/.claude/` |
| Codex | `codex/` | `~/.codex/` |

## Known Issues

### noice.nvim crashes

noice.nvim can cause nvim to crash when pressing `:` to enter command mode. This is due to
incompatibility with certain Neovim versions (seen with 0.11.5). Fix: disable noice in
`nvim/.config/nvim/lua/plugins/noice.lua` with `enabled = false`. Noice is purely cosmetic
(fancy command line and notification UI) so disabling it doesn't affect functionality.
