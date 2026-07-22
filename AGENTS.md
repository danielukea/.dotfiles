# AGENTS.md

Guidance for any coding agent working in this repository. (Claude Code also reads
`CLAUDE.md`; Codex and other agents read this file.)

## What this repo is

A personal dotfiles repo managed with **GNU Stow**. Each top-level directory is a
"package" that mirrors `$HOME` and gets symlinked into place. See `README.md` and
`CLAUDE.md` for full architecture, commands, and known issues.

## Skills — read before authoring

Agent skills live in `agents/.agents/skills/` and stow to `~/.agents/skills/` — the
cross-tool universal standard read natively by Claude Code, Codex, and Gemini CLI.
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

## Tool-specific config packages

| Tool | Stow package | Stows to | Context file |
|------|-------------|----------|-------------|
| All agents | `agents/` | `~/.agents/` | `AGENTS.md` (this file) |
| Claude Code | `claude/` | `~/.claude/` | `CLAUDE.md` |
| Codex | `codex/` | `~/.codex/` | `~/.codex/AGENTS.md` |
| Gemini CLI | `gemini/` (future) | `~/.gemini/` | `~/.gemini/GEMINI.md` |
