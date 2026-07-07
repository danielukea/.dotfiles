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

Follow the steps and report format in `~/.agents/HEALTHCHECK.md` — that file is the
single source of truth so Claude Code, Codex, and any other agent run the same
checklist. This SKILL.md exists only so Claude Code's Skill tool can discover it by
name/description; don't duplicate the steps here.
