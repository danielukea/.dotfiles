---
name: healthcheck
description: >
  Self-evaluation skill for any agent to verify its own skill configuration.
  Run when asked to "healthcheck", "verify my skills", or "check my setup".
  Lists ~/.agents/skills/, verifies SKILL.md presence with find -L (required
  for stow-managed symlinks), spot-checks a skill, and confirms docs access.
  Returns a structured report: skills found, missing SKILL.md, docs accessible.
allowed-tools: Bash, Read
---

# Agent Skill Healthcheck

Self-evaluation of the agent's skill configuration. Run each step and report findings.

## Steps

1. **Identify yourself** — state the agent tool (Claude Code, Codex, Gemini, etc.)

2. **List skills** — `ls ~/.agents/skills/` and report each entry

3. **Verify integrity** — confirm each skill directory contains a SKILL.md:
   ```
   find -L ~/.agents/skills -maxdepth 2 -name "SKILL.md" | sort
   ```
   Note: `-L` follows stow-managed symlinks into dotfiles skill directories.
   A directory in `~/.agents/skills/` with no SKILL.md is an artifact, not a skill.

4. **Spot-check** — read `~/.agents/skills/design-principles/SKILL.md` first line of the description

5. **Docs check** — confirm `~/.agents/docs/` is accessible: `ls ~/.agents/docs/`

## Report Format

| Skill | SKILL.md present | Notes |
|-------|-----------------|-------|
| arch-analysis | ✓ | |
| healthcheck | ✓ | |

Summary:
- **Tool**: [agent name]
- **Skills found**: [count]
- **Skills missing SKILL.md**: [list or "none"]
- **Docs accessible**: [yes/no]
- **Overall**: PASS / FAIL
