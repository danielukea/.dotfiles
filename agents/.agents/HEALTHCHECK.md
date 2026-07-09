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

6. **Skill/agent usage logging** — verify the logger is actually functional, not just
   that old log files happen to exist. Same check for every agent tool (Claude Code,
   Codex, ...) since they share one script:
   ```bash
   SCRIPT=~/.agents/scripts/agent-usage-logger.sh
   [ -x "$SCRIPT" ] && echo "script present and executable" || echo "MISSING: $SCRIPT"

   # Synthetic round-trip through the real script, into a throwaway dir — never
   # writes to the real logs.
   TESTDIR=$(mktemp -d)
   echo '{"tool_name":"Skill","cwd":"'"$TESTDIR"'","session_id":"healthcheck","tool_input":{"skill":"healthcheck-selftest"}}' \
     | AGENT_USAGE_LOG_DIR="$TESTDIR" "$SCRIPT" claude
   if jq -e '.skill == "healthcheck-selftest" and .source == "claude" and .detection == "explicit"' \
       "$TESTDIR/skill-usage.jsonl" >/dev/null 2>&1; then
     echo "logger round-trip: PASS"
   else
     echo "logger round-trip: FAIL"
   fi
   rm -rf "$TESTDIR"

   # Real logs: recency + silent-failure visibility.
   ls -la ~/.claude/logs/skill-usage.jsonl ~/.claude/logs/agent-usage.jsonl 2>/dev/null || echo "no real logs yet"
   if [ -s ~/.claude/logs/logger-errors.log ]; then
     echo "logger-errors.log has entries — logging may be silently broken:"
     tail -5 ~/.claude/logs/logger-errors.log
   else
     echo "no logger errors recorded"
   fi
   ```
   A PASS on the round-trip only proves the script itself works. It does NOT prove the
   *hook wiring* fires for this specific tool — Claude Code's `Skill`/`Agent` matchers
   and Codex's `spawn_agent`/`Bash` matchers must independently match that tool's real
   hook payload (confirmed empirically 2026-07-09; don't assume a tool's model-facing
   tool name is what the hook matcher sees — Codex's shell tool is `exec_command` to
   the model but `Bash` to the hook). If real-log recency looks stale despite recent
   skill/agent use, suspect a matcher mismatch, not the script.

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
- **Logger round-trip**: PASS / FAIL
- **Real logs last written**: [timestamp or "not yet written"]
- **Logger errors**: [none / N recent — see logger-errors.log]
- **Overall**: PASS / FAIL
