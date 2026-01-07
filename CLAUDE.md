# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a personal dotfiles repository using GNU Stow for symlink management. Each top-level directory represents a "package" that gets symlinked to the home directory.

## Commands

### Installation
```bash
./install.sh              # Full setup: unlinks, re-links dotfiles, runs brew bundle
./link.sh link            # Symlink all dotfiles packages to ~
./link.sh unlink          # Remove all symlinks from ~
```

### Adding New Configurations
1. Create a new directory at the repo root (e.g., `newapp/`)
2. Mirror the home directory structure inside (e.g., `newapp/.config/newapp/config.toml`)
3. Run `./link.sh link` to symlink

## Architecture

### Package Structure
Each directory is a Stow package that mirrors `$HOME`:
- `brew/` - Brewfile for Homebrew dependencies
- `claude/` - Claude Code configuration (`.claude/` settings, agents, commands, templates)
- `kitty/` - Terminal emulator config (`.config/kitty/`)
- `mise/` - Tool version manager config (`.config/mise/`)
- `nvim/` - LazyVim-based Neovim config (`.config/nvim/`)
- `tmux/` - Tmux config (`.tmux.conf`)
- `zsh/` - Zsh shell config (`.zshrc`, oh-my-zsh as submodule)

### Claude Code Configuration
The `claude/` package contains:
- `.claude/settings.json` - Default model, plugins, status line
- `.claude/agents/` - Custom agent definitions (code-architect, design-system-expert, rails-pattern-expert, etc.)
- `.claude/commands/` - Slash commands (take-notes, remember-note, vibe-this)
- `.claude/templates/` - Spec templates for bugs, features, refactors

### Tool Management
Uses `mise` (not asdf) for runtime version management. Global tools are defined in `mise/.config/mise/config.toml`.

### Tmux Keybindings
Prefix is `C-s` (not `C-b`). Vim-style pane navigation: `h/j/k/l`. Split with `|` and `-`.
