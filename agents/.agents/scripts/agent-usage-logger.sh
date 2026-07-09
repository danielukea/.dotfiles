#!/usr/bin/env bash
# agent-usage-logger.sh <source> — portable skill/agent usage logger for Claude Code & Codex.
#
# <source> is passed positionally by each tool's own hook config (never sniffed from
# env/payload) so a third tool can be wired in later by adding its own hook config
# block that calls this script with its own identity string — no script change needed.
#
# Wired to hooks in:
#   ~/.claude/settings.json  → PostToolUse matcher "Skill"/"Agent"                 → "claude"
#   ~/.codex/hooks.json      → PostToolUse matcher "spawn_agent"/"Bash"            → "codex"
#
# Codex has no discrete "skill invoked" tool call — skills are injected as ambient
# context and the model opens the SKILL.md itself via a shell command. The Bash
# branch below approximates skill usage by scanning the command for a
# `skills/<name>/SKILL.md` path and tags it detection:"inferred" (vs "explicit" for
# Claude's real Skill tool call) so downstream consumers can weight it as a weaker
# signal. It misses skills reasoned about without opening the file, and has no
# visibility into Codex's VS Code app-server path (a separate mechanism, no hooks).
#
# Non-obvious: Codex's own shell-exec tool is "exec_command" in its model-facing
# tool schema (visible in session transcripts), but its PostToolUse hook payload
# reports tool_name:"Bash" with tool_input.command — Codex aliases it to Claude
# Code's own Bash tool shape for hook-ecosystem compatibility. Confirmed empirically
# 2026-07-09 (a matcher of "exec_command" silently never fires; "Bash" does). Codex's
# spawn_agent tool is NOT aliased — its hook tool_name is the literal "spawn_agent".
#
# Reads the hook's JSON event on stdin, appends one JSON object per line to
# skill-usage.jsonl / agent-usage.jsonl. ALWAYS exits 0 — a parse failure must never
# block the agent. If jq is missing or stdin is empty, records to logger-errors.log
# instead of silently producing zero data forever.
#
# Output schemas (consumed by the skill-prune skill — keep these stable):
#   skill-usage.jsonl : {ts, source, cwd, session_id, skill, detection}
#   agent-usage.jsonl : {ts, source, cwd, session_id, agent_type, description}

set +e

LOG_DIR="${AGENT_USAGE_LOG_DIR:-$HOME/.claude/logs}"
mkdir -p "$LOG_DIR" 2>/dev/null

source_tag="${1:-unknown}"
ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

errlog() { printf '%s\t%s\t%s\n' "$ts" "$source_tag" "$1" >> "$LOG_DIR/logger-errors.log" 2>/dev/null; }

if ! command -v jq >/dev/null 2>&1; then
  errlog "jq not found on PATH"
  exit 0
fi

input="$(cat 2>/dev/null)"
if [ -z "$input" ]; then
  errlog "empty stdin"
  exit 0
fi

get() { printf '%s' "$input" | jq -r "$1" 2>/dev/null; }

cwd="$(get '.cwd // .workspace_roots[0] // empty')"
if [ -z "$cwd" ] || [ "$cwd" = "null" ]; then cwd="$PWD"; fi

session_id="$(get '.session_id // .conversation_id // empty')"
tool="$(get '.tool_name // empty')"

json_line() {
  jq -nc --arg ts "$ts" --arg source "$source_tag" --arg cwd "$cwd" --arg session_id "$session_id" "$@"
}

case "$tool" in
  Skill)
    skill="$(get '.tool_input.skill // empty')"
    if [ -n "$skill" ] && [ "$skill" != "null" ]; then
      json_line --arg skill "$skill" --arg detection "explicit" \
        '{ts:$ts, source:$source, cwd:$cwd, session_id:$session_id, skill:$skill, detection:$detection}' \
        >> "$LOG_DIR/skill-usage.jsonl"
    fi
    ;;
  Agent|spawn_agent)
    agent_type="$(get '.tool_input.subagent_type // .tool_input.agent_type // "general-purpose"')"
    desc="$(get '.tool_input.description // .tool_input.message // empty' | cut -c1-200)"
    json_line --arg agent_type "$agent_type" --arg description "$desc" \
      '{ts:$ts, source:$source, cwd:$cwd, session_id:$session_id, agent_type:$agent_type, description:$description}' \
      >> "$LOG_DIR/agent-usage.jsonl"
    ;;
  Bash|exec_command)
    cmd="$(get '.tool_input.command // .tool_input.cmd // empty')"
    # skills/<name>/SKILL.md for shared skills, skills/.system/<name>/SKILL.md for Codex's
    # own native skills — match any depth, take the segment immediately before SKILL.md.
    skill="$(printf '%s' "$cmd" | grep -oE 'skills(/[^/[:space:]"'"'"']+)+/SKILL\.md' | head -1 | sed -E 's#.*/([^/]+)/SKILL\.md#\1#')"
    if [ -n "$skill" ]; then
      json_line --arg skill "$skill" --arg detection "inferred" \
        '{ts:$ts, source:$source, cwd:$cwd, session_id:$session_id, skill:$skill, detection:$detection}' \
        >> "$LOG_DIR/skill-usage.jsonl"
    fi
    ;;
esac

exit 0
