#!/usr/bin/env bash
# agent-usage-logger.sh — portable skill/agent usage logger for Claude Code & Codex.
#
# Wired to PostToolUse hooks (matcher "Skill" / "Agent") in:
#   ~/.claude/settings.json   (Claude Code)
#   ~/.codex/hooks.json       (Codex CLI)
#
# It reads the hook's JSON event on stdin, appends a normalized TSV line, and
# ALWAYS exits 0 — a parse failure must never block the agent (exit 2 blocks in
# Claude Code, Codex, Cursor, and Gemini alike).
#
# Portability: stdin JSON is the only channel that is portable across agents;
# env vars are not (only Claude Code exposes CLAUDE_*). Field access uses
# fallbacks (.cwd // .workspace_roots[0], .session_id // .conversation_id) so the
# same script works if wired into other agents later. "Skill" is a Claude/Codex
# concept; other agents would only ever hit the generic branch.
#
# Output (consumed by the skill-prune skill — keep these formats stable):
#   skill-usage.log : <ISO8601>\t<cwd>\t<skill-name>
#   agent-usage.log : <ISO8601>\t<cwd>\t<subagent_type>\t<description>

set +e

LOG_DIR="${AGENT_USAGE_LOG_DIR:-$HOME/.claude/logs}"
mkdir -p "$LOG_DIR" 2>/dev/null

input="$(cat 2>/dev/null)"
get() { printf '%s' "$input" | jq -r "$1" 2>/dev/null; }

ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

cwd="$(get '.cwd // .workspace_roots[0] // empty')"
if [ -z "$cwd" ] || [ "$cwd" = "null" ]; then cwd="$PWD"; fi

tool="$(get '.tool_name // empty')"

case "$tool" in
  Skill)
    skill="$(get '.tool_input.skill // empty')"
    if [ -n "$skill" ] && [ "$skill" != "null" ]; then
      printf '%s\t%s\t%s\n' "$ts" "$cwd" "$skill" >> "$LOG_DIR/skill-usage.log"
    fi
    ;;
  Agent)
    subagent="$(get '.tool_input.subagent_type // "general-purpose"')"
    desc="$(get '.tool_input.description // empty')"
    printf '%s\t%s\t%s\t%s\n' "$ts" "$cwd" "$subagent" "$desc" >> "$LOG_DIR/agent-usage.log"
    ;;
esac

exit 0
