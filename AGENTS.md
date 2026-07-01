# AGENTS.md

Guidance for any coding agent working in this repository. (Claude Code also reads
`CLAUDE.md`; Codex and other agents read this file.)

## What this repo is

A personal dotfiles repo managed with **GNU Stow**. Each top-level directory is a
"package" that mirrors `$HOME` and gets symlinked into place. See `README.md` and
`CLAUDE.md` for full architecture, commands, and known issues.

## Skills — read before authoring

Agent skills live in `claude/.claude/skills/` and are symlinked into `~/.claude/skills`
(and read by Codex via `~/.codex/hooks.json` / `AGENTS.md`). **Before creating or editing
any skill, read [`claude/.claude/docs/SKILLS.md`](claude/.claude/docs/SKILLS.md)** — it
captures the principles for what makes a skill valuable (teach durable knowledge, don't
railroad judgment tasks; separate knowledge skills from orchestration; put project-specific
conventions in that project's rules, not in a portable skill).

Keep skills **dotfiles-canonical**: author them here, then run `./link.sh link`. A skill
name that also exists in `~/.agents/skills` breaks the stow re-link — make this repo the
single source.

## Conventions

- After changing skills or other stowed files, run `./link.sh link`.
- Skill/agent usage is logged by a portable `PostToolUse` hook
  (`scripts/agent-usage-logger.sh`) → `~/.claude/logs/`. Wired into both Claude Code
  (`claude/.claude/settings.json`) and Codex (`~/.codex/hooks.json`).
- Commit or push only when asked. This repo commits directly to `main` (a background
  agent auto-syncs via `git pull --ff-only` every 5 minutes).
