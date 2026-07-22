# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a personal dotfiles repository using GNU Stow for symlink management. Each top-level directory represents a "package" that gets symlinked to the home directory.

**Supported platforms:** macOS and Ubuntu/Debian Linux

## Commands

### Installation

```bash
./install.sh              # Full setup: unlinks, re-links dotfiles, installs packages
./link.sh link            # Symlink all dotfiles packages to ~
./link.sh unlink          # Remove all symlinks from ~
```

The install script auto-detects the OS:

- **macOS**: Uses `brew bundle` with `brew/Brewfile`
- **Ubuntu/Debian**: Uses `apt` with `packages.apt`, plus manual installs for mise, scmpuff, lazygit

### Adding New Configurations

1. Create a new directory at the repo root (e.g., `newapp/`)
2. Mirror the home directory structure inside (e.g., `newapp/.config/newapp/config.toml`)
3. Run `./link.sh link` to symlink

## Architecture

### Package Structure

Each directory is a Stow package that mirrors `$HOME`:

- `agents/` - Agent-agnostic config (`.agents/skills/`, `.agents/docs/`, `.agents/HEALTHCHECK.md`) shared across Claude Code, Codex, Gemini CLI
- `brew/` - Brewfile for Homebrew dependencies (macOS)
- `packages.apt` - apt package list (Ubuntu/Debian)
- `claude/` - Claude Code configuration (`.claude/` settings, commands, templates) — skills live in `agents/`, not here
- `codex/` - Codex config (`.codex/` AGENTS.md, hooks.json, rules)
- `kitty/` - Terminal emulator config (`.config/kitty/`)
- `launchd/` - macOS LaunchAgents for background tasks (`Library/LaunchAgents/`)
- `mise/` - Tool version manager config (`.config/mise/`)
- `nvim/` - LazyVim-based Neovim config (`.config/nvim/`)
- `scripts/` - Utility scripts used by launchd and other automation (not stowed, used in-place)
- `tmux/` - Tmux config (`.tmux.conf`)
- `zsh/` - Zsh shell config (`.zshrc`, oh-my-zsh as submodule)

### Claude Code Configuration

The `claude/` package contains:

- `.claude/settings.json` - Default model, plugins, status line
- `.claude/commands/` - Slash commands (take-notes, remember-note, vibe-this)
- `.claude/templates/` - Spec templates for bugs, features, refactors

Skills are NOT under `claude/` — they're dotfiles-canonical under `agents/.agents/skills/`
(agent-agnostic, shared with Codex/Gemini CLI), and `link.sh` auto-bridges them into
`~/.claude/skills/` since Claude Code only discovers skills there. Add/edit skills under
`agents/.agents/skills/<name>/`; run `./link.sh link` if a new one isn't showing up yet. Full
bridging mechanism: see "Maintenance" in [~/.agents/docs/SKILLS.md](~/.agents/docs/SKILLS.md).

Custom subagents were retired in favor of composable skills; orchestration skills fan out
`general-purpose` subagents that `Skill`-load the relevant knowledge skill.

### Tool Management

Uses `mise` (not asdf) for runtime version management. Global tools are defined in `mise/.config/mise/config.toml`.

### Tmux Keybindings

Prefix is `C-s` (not `C-b`). Vim-style pane navigation: `h/j/k/l`. Split with `|` and `-`.

### Auto-Sync

Dotfiles automatically sync from GitHub every 5 minutes via a macOS launchd agent. When changes are detected, it pulls and re-runs `./link.sh link` to apply new symlinks.

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

## Known Issues

### noice.nvim crashes

noice.nvim can cause nvim to crash when pressing `:` to enter command mode. This is due to incompatibility with certain Neovim versions (seen with 0.11.5). Fix: disable noice in `nvim/.config/nvim/lua/plugins/noice.lua` with `enabled = false`. Noice is purely cosmetic (fancy command line and notification UI) so disabling it doesn't affect functionality.
