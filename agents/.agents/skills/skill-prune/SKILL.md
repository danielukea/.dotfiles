---
name: skill-prune
description: Audit installed skills against the usage log and report never-used, stale, and low-use skills with concrete disposal commands. Opt for disabling via skillOverrides before deletion; never delete automatically.
disable-model-invocation: true
argument-hint: "[days-threshold]"
allowed-tools: Read, Bash, Glob, Grep
---

# Skill Prune

Identify installed skills that are unused or rarely used, so the user can disable or delete them and reduce per-turn context cost.

## Inputs

- **Usage log**: `~/.claude/logs/skill-usage.log` (tab-separated: `timestamp<TAB>cwd<TAB>skill-name`, populated by the `PostToolUse:Skill` hook).
- **Installed skills**: `~/.claude/skills/*/SKILL.md` (includes symlinks into `~/.dotfiles/claude/.claude/skills/`, `~/.agents/skills/`, and standalone dirs).
- **Agent files** (for cross-reference): `~/.claude/agents/*.md`, `~/.dotfiles/claude/.claude/agents/*.md`.
- **Threshold**: if the user passed a number as an argument, treat it as "days since last use" cutoff. Default: 30.

## Why this exists

Every installed skill's `name` and `description` ship in the per-turn context via `available_skills`. Roughly 50–200 tokens per skill, paid every turn. Dozens of unused skills is real context tax. But skills referenced by custom agents, or recently installed, should be preserved — this skill surfaces candidates with enough evidence for the user to decide.

## Procedure

### 1. Sanity-check the log

```bash
[ -f ~/.claude/logs/skill-usage.log ] && wc -l ~/.claude/logs/skill-usage.log || echo "no log yet"
```

If the log is missing or has fewer than ~20 lines, tell the user the data is too thin to draw conclusions and to re-run after more usage. Stop.

### 2. Build the usage summary

```bash
awk -F'\t' '{count[$3]++; last[$3]=$1} END {for (s in count) printf "%s\t%d\t%s\n", s, count[s], last[s]}' ~/.claude/logs/skill-usage.log | sort -k2 -n
```

Columns: `skill-name`, `invocation-count`, `last-used-timestamp`.

### 3. List installed skills with mtime

```bash
for d in ~/.claude/skills/*/; do
  [ -f "$d/SKILL.md" ] || continue
  name=$(basename "$d")
  target=$(readlink "$d" 2>/dev/null || echo "$d")
  mtime=$(stat -f '%Sm' -t '%Y-%m-%d' "$d/SKILL.md" 2>/dev/null || stat -c '%y' "$d/SKILL.md" | cut -d' ' -f1)
  echo "$name"$'\t'"$target"$'\t'"$mtime"
done | sort
```

Columns: `skill-name`, `resolved-path`, `install-date`.

### 4. Find skill references in custom agents

Before recommending removal, check which skills are hardcoded into agent instructions. Deleting a referenced skill silently breaks the agent.

```bash
grep -hrE '`[a-z0-9-]+(:?[a-z0-9-]+)?`' ~/.claude/agents ~/.dotfiles/claude/.claude/agents 2>/dev/null | grep -oE '`[a-z0-9-]+`' | tr -d '`' | sort -u
```

Anything in this list that shows up as a prune candidate should be flagged as "referenced by agent" rather than "prune candidate." Do a targeted grep to show which agent file references it.

### 5. Categorize

Exclusions that apply to all buckets:
- **Plugin-namespaced skills** (names containing `:` like `wealthbox:linear`) — managed by `/plugin`, not by deleting directories.
- **Self-dependencies**: `update-config`, `find-skills`, `skill-prune`.
- **Recently installed**: `install-date` within the last 7 days — too new to judge.
- **Agent-referenced skills** (from step 4): demote from "prune" to "flagged" with the agent reference shown.

Then sort into three buckets:

- **Never used** — installed ≥ 7 days AND not in log at all. Strongest prune candidates.
- **Stale** — last used > threshold days ago. Likely prune candidates.
- **Low-use but recent** — used within threshold but ≤ 3 total invocations. Flag, don't recommend.

The stale threshold being user-configurable matters more than a count floor — a skill used once 60 days ago is a stronger prune candidate than one used twice yesterday.

### 6. Present output

Use this exact structure:

```
# Skill Prune Report

**Log window**: {first-timestamp} → {last-timestamp} ({N} invocations)
**Threshold**: {N} days

## Never used (strong prune candidates)

### {skill-name}
- Installed: {install-date}
- Path: {resolved-path}
- Disable (soft):   add "{skill-name}": "off" to skillOverrides in ~/.claude/settings.json
- Delete (hard):    rm -rf {resolved-path}   # symlink only — source at {link-target} remains

## Stale (likely prune candidates)

### {skill-name}
- Last used: {last-used-timestamp} ({N} days ago)
- Invocations: {count}
- Path: {resolved-path}
- Disable (soft):   ...
- Delete (hard):    ...

## Low-use but recent (flagged only)

- {skill-name}: {count} uses, last {days-ago} days ago

## Agent-referenced (not safe to delete)

- {skill-name}: referenced in {agent-file} — would break that agent's instructions

## Summary

- Installed skills (excluding plugins): {N}
- Prune candidates: {never-used count} never-used + {stale count} stale = {total}
- Estimated context savings if all pruned: ~{N × 100} tokens per turn (rough — varies with description length)
```

### 7. Recommend disposal strategy

After the report, tell the user:

> **Prefer `skillOverrides` to deletion for first-pass cleanup.** Setting a skill to `"off"` in `~/.claude/settings.json` hides it from Claude without deleting files — easy to reverse if you miss it. Only delete after a second pass confirms you don't want it back.

Provide a ready-to-paste `skillOverrides` block combining all never-used + stale candidates:

```json
"skillOverrides": {
  "skill-a": "off",
  "skill-b": "off"
}
```

Note that for symlinked skills, hard deletion should target the source directory (e.g. `~/.agents/skills/<name>` for PatternsDev, `~/.dotfiles/claude/.claude/skills/<name>` for stow-managed). Removing only the symlink leaves orphaned source data. For stow-managed skills, mention that the user may want to run `stow -D claude` from `~/.dotfiles` after removing directories.

**Never delete automatically.** Present evidence and commands; the user runs them.

## Notes

- The usage log captures every `Skill` tool invocation — model auto-activations and explicit user `/skill-name` calls both count.
- Skills invoked inside subagents are logged, but the `cwd` column reflects the parent session.
- A skill not in the log may still be providing value by appearing in `available_skills` and influencing model decisions without being formally invoked. The `description` text alone can steer behavior. This tool can't detect that — treat the report as a starting point for the user's judgment, not a verdict.
