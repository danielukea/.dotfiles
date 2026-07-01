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
4. **~/.claude/skills/ state** — run `ls ~/.claude/skills/` — this should contain ONLY
   marketplace skills (ai-ui-patterns, find-skills, etc.), NOT dotfiles skills.
   Dotfiles skills now live in `~/.agents/skills/` and Claude reads both paths.

## Extended Report

Append to the standard report:

- **Claude settings readable**: [yes/no]
- **Commands dir accessible**: [yes/no]
- **Skill usage log**: [last write time or "not yet written"]
- **~/.claude/skills/ dotfiles-free**: [yes — only marketplace / no — dotfiles skills still present]
