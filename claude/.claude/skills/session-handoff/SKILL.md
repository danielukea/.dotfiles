---
name: session-handoff
description: "Create a structured handoff checkpoint before ending a session. Captures git state, design decisions, open investigation threads, and uncommitted work into a .handoff.md file so the next session can pick up without re-exploring. Use when the user says 'handoff', 'session handoff', 'checkpoint', 'wrap up', 'save state', 'I'm done for now', or wants to capture context before closing a session."
user-invocable: true
---

# Session Handoff

Create a `.handoff.md` checkpoint that preserves session context for future sessions. This exists because context evaporates between sessions — design decisions get re-explored, investigation threads get silently dropped, and document state gets re-fetched minutes after the last session touched it.

## Why This Matters

From analysis of real session data, the top causes of wasted time across sessions are:
1. **Design decisions re-explored** — the next session doesn't know what was decided or why
2. **Open threads silently dropped** — bugs found but not fixed disappear when the session ends
3. **Uncommitted work at risk** — long sessions with many changes but 0 commits lose everything on a crash
4. **Environment state forgotten** — what services were running, what seed data existed, what flags were enabled

A 2-minute handoff saves 10-15 minutes of re-establishment in the next session.

## When to Run

Run this skill:
- Before closing a long session (30+ minutes)
- When switching to a different task/branch
- When you've made design decisions that aren't captured in code comments or commits
- When you've found bugs or issues you haven't fixed yet
- When context window compression is approaching

## Handoff Process

### Step 1: Gather State

Run these in parallel to understand the current situation:

```
git status                           # What's modified/staged/untracked
git diff --stat                      # Size of uncommitted changes
git log --oneline -5                 # Recent commits for context
git branch --show-current            # Current branch
```

Also scan the conversation for:
- Decisions the user made (rejected approaches, style preferences, architecture choices)
- Bugs or issues discovered but not yet fixed
- Things the user said they'd come back to
- Any "TODO" or "investigate later" moments

### Step 2: Assess Commit Risk

Count uncommitted lines. If significant work is uncommitted (50+ lines changed), flag it prominently. The handoff note is not a substitute for committing — it's a safety net for context, not code.

If there are uncommitted changes, ask the user:
> "You have ~{N} uncommitted lines across {M} files. Want me to commit before writing the handoff?"

Respect their answer — some people intentionally leave work uncommitted.

### Step 3: Write .handoff.md

Write the handoff file to the root of the current git worktree (or working directory if not in a git repo). If a `.handoff.md` already exists, archive it by renaming to `.handoff.{date}.md` before writing the new one.

Use this structure:

```markdown
# Session Handoff
**Date:** {YYYY-MM-DD HH:MM}
**Branch:** {branch-name}
**Working directory:** {path}

## What I Was Working On
{1-3 sentence summary of the session's goal and where it got to}

## Decisions Made
{Bulleted list of design/architecture/style decisions with brief rationale}
- **Decision:** {what was decided}
  **Why:** {the reasoning}
  **Alternatives rejected:** {what was considered and dropped}

## Open Threads
{Things discovered but not resolved — bugs, questions, investigations paused mid-stream}
- [ ] {description of open item}
  **Context:** {what you know so far, where to look}

## Uncommitted State
**Files changed:** {N}
**Lines:** +{added}/-{removed}

{If significant uncommitted work exists:}
Key changes not yet committed:
- {file}: {what changed and why}

## Next Steps
{What the next session should do first, in priority order}
1. {highest priority action}
2. {next action}

## Environment Notes
{Only include if relevant — services running, feature flags, seed data state, etc.}
```

### Step 4: Save Key Decisions to Memory

If the session produced design decisions or user preferences that will matter beyond this branch, save them to the Claude memory system (not just the handoff file). The handoff file is branch-scoped and temporary; memory persists across all sessions.

Good candidates for memory:
- Code style preferences the user expressed ("prefer explicit methods over metaprogramming")
- Architecture decisions that affect the broader project
- Workflow preferences ("don't split this into multiple PRs")

Skip saving to memory for:
- Branch-specific implementation details
- Temporary environment state
- Anything already captured in a commit message or PR description

### Step 5: Confirm

After writing, show the user a brief summary:
- Where the handoff file was written
- How many open threads were captured
- Whether there's uncommitted work flagged
- Any items saved to memory

## Reading a Previous Handoff

At the start of a new session in a worktree, if `.handoff.md` exists, read it before doing anything else. It tells you:
- What the previous session was working on
- What decisions were already made (don't re-explore these)
- What open threads need attention
- What the recommended next step is

After reading, briefly acknowledge to the user: "I see a handoff from {date} — picking up from {summary}. The main open items are: {list}."

If the handoff is stale (more than 3 days old), mention that and suggest the user confirm priorities before proceeding.
