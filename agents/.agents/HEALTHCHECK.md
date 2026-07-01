# Agent Skill Healthcheck

You are performing a self-evaluation of your skill configuration. Run each step
using your available tools (bash, file read, etc.) and report findings.

## Steps

1. **Identify yourself** — state the agent tool you are running under (Claude Code, Codex, Gemini, etc.)

2. **List skills** — run `ls ~/.agents/skills/` and report each entry

3. **Verify integrity** — confirm each skill directory contains a SKILL.md:
   ```
   find -L ~/.agents/skills -maxdepth 2 -name "SKILL.md" | sort
   ```
   Note: `-L` is required to follow stow-managed symlinks into dotfiles skill directories.

4. **Spot-check** — read `~/.agents/skills/design-principles/SKILL.md` and
   confirm it loads (report the first line of the description field)

5. **Docs check** — confirm `~/.agents/docs/` is accessible:
   ```
   ls ~/.agents/docs/
   ```

## Report Format

Output a markdown table:

| Skill | SKILL.md present | Description (first line) |
|-------|-----------------|--------------------------|
| arch-analysis | ✓ | ... |

Then a summary block:
- **Tool**: [agent name]
- **Skills found**: [count]
- **Skills missing SKILL.md**: [list or "none"]
- **Docs accessible**: [yes/no]
- **Spot-check passed**: [yes/no]
- **Overall**: PASS / FAIL
