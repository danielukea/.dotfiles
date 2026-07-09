#!/usr/bin/env bash
# skill-usage-report.sh — quick jq-based CLI view over the skill/agent usage logs.
#
# Reads skill-usage.jsonl / agent-usage.jsonl (written by agent-usage-logger.sh) and
# prints: top skills/agents with an explicit/inferred + claude/codex split, usage by
# cwd, and an 8-week trend. Complements skill-prune (which focuses on prune
# decisions) with a faster, unopinionated "what's happening" view.

set -e

LOG_DIR="${AGENT_USAGE_LOG_DIR:-$HOME/.claude/logs}"
SKILL_LOG="$LOG_DIR/skill-usage.jsonl"
AGENT_LOG="$LOG_DIR/agent-usage.jsonl"

section() { printf '\n== %s ==\n' "$1"; }

if [ -f "$SKILL_LOG" ]; then
  section "Top skills (count, explicit/inferred, claude/codex, last used)"
  jq -s '
    group_by(.skill) | map({
      skill: .[0].skill,
      count: length,
      explicit: (map(select(.detection == "explicit")) | length),
      inferred: (map(select(.detection == "inferred")) | length),
      claude: (map(select(.source == "claude")) | length),
      codex: (map(select(.source == "codex")) | length),
      last: (map(.ts) | max)
    }) | sort_by(-.count)
  ' "$SKILL_LOG" | jq -r '.[] | [.skill, .count, "\(.explicit)e/\(.inferred)i", "\(.claude)c/\(.codex)x", .last] | @tsv' | \
    column -t -s $'\t'

  section "Usage by project (cwd)"
  jq -s 'group_by(.cwd) | map({cwd: .[0].cwd, count: length}) | sort_by(-.count)' "$SKILL_LOG" | \
    jq -r '.[] | [.count, .cwd] | @tsv' | column -t -s $'\t'

  section "Weekly trend (skill invocations, last 8 weeks)"
  jq -r '.ts[0:10]' "$SKILL_LOG" | while read -r d; do date -j -f '%Y-%m-%d' "$d" '+%Y-W%V' 2>/dev/null; done | \
    sort | uniq -c | awk '{print $2, $1}' | sort | tail -8
else
  echo "No skill-usage.jsonl yet at $SKILL_LOG"
fi

if [ -f "$AGENT_LOG" ]; then
  section "Top agent types (count, claude/codex)"
  jq -s '
    group_by(.agent_type) | map({
      agent_type: .[0].agent_type,
      count: length,
      claude: (map(select(.source == "claude")) | length),
      codex: (map(select(.source == "codex")) | length)
    }) | sort_by(-.count)
  ' "$AGENT_LOG" | jq -r '.[] | [.agent_type, .count, "\(.claude)c/\(.codex)x"] | @tsv' | column -t -s $'\t'
else
  echo "No agent-usage.jsonl yet at $AGENT_LOG"
fi
