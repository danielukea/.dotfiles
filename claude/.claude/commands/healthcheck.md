---
description: Run agent skill healthcheck — verify ~/.agents/skills/ and Claude-specific config
---

Run the agent skill healthcheck. Follow the steps in `~/.agents/HEALTHCHECK.md`, then
add the Claude Code-specific checks below.

## Claude Code Extras

After the standard healthcheck, also verify:

1. **Settings** — confirm `~/.claude/settings.json` is readable and contains `"model":`
2. **Commands** — list `~/.claude/commands/` and confirm this file is present
3. **Skill log** — check whether `~/.claude/logs/skill-usage.log` exists and when it
   was last written to: `ls -la ~/.claude/logs/skill-usage.log 2>/dev/null || echo "No log yet"`
4. **~/.claude/skills/ bridge** — Claude Code only discovers skills under `~/.claude/skills/`,
   NOT `~/.agents/skills/` directly (confirmed 2026-07-07: every dotfiles-canonical skill was
   invisible to Claude Code for a week until this was diagnosed). `link.sh`'s
   `bridge_claude_skills` step symlinks every `~/.agents/skills/*` entry into
   `~/.claude/skills/*`. Run `diff <(ls ~/.agents/skills/) <(ls ~/.claude/skills/)` — every
   name in `~/.agents/skills/` must also appear in `~/.claude/skills/` (as a symlink back into
   `~/.agents/skills/`). If any are missing, run `./link.sh link` from the dotfiles root to
   re-bridge, then re-check.

## Extended Report

Append to the standard report:

- **Claude settings readable**: [yes/no]
- **Commands dir accessible**: [yes/no]
- **Skill usage log**: [last write time or "not yet written"]
- **~/.claude/skills/ fully bridged**: [yes — every ~/.agents/skills/ entry has a matching symlink / no — list what's missing and re-run `./link.sh link`]
