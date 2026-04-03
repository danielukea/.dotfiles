---
name: next-issue
description: >
  Suggest the next Linear issue to pick up from a project. Analyzes issue
  dependencies, blockers, and what's already in progress to recommend the
  highest-value unblocked issue that nobody is working on. Assigns it to you
  and kicks off planning. Use this skill when the user says "what should I work
  on next", "next issue", "pick up next task", "what's next in the project",
  "suggest next issue", "what's unblocked", or wants help choosing work from
  a Linear project. Also use when the user mentions a Linear project and seems
  to be looking for their next task.
user-invokeable: true
allowed-tools: AskUserQuestion, mcp__claude_ai_Linear__list_projects, mcp__claude_ai_Linear__list_issues, mcp__claude_ai_Linear__get_issue, mcp__claude_ai_Linear__save_issue, mcp__claude_ai_Linear__get_authenticated_user, mcp__claude_ai_Linear__list_issue_statuses
---

# Next Issue

Pick the best next issue from a Linear project and start planning it together.

## Step 1: Identify the project

If the user provided a project name or URL, use it. Otherwise, list their
projects with `list_projects` and ask which one.

## Step 2: Get context

Run these in parallel:
- `get_authenticated_user` — need the user's ID for assignment
- `list_issues` for the project — get all issues with their status, assignee,
  and priority
- `list_issue_statuses` for the team — understand which statuses mean
  "in progress" vs "todo" vs "done"

## Step 3: Find candidates

Filter issues to find good candidates. A good candidate is:

1. **Not done** — status is not "Done", "Canceled", or "Completed"
2. **Not in progress** — status is "Todo", "Backlog", "Unstarted", or similar
   (not "In Progress", "In Review", etc.)
3. **Not assigned** — no current assignee, or assigned to the user already
4. **Not blocked** — check if the issue description or relations mention
   blockers. If an issue depends on another issue that isn't done, skip it.

From the candidates, rank by:
- **Priority first** — urgent > high > medium > low > none
- **Dependencies second** — issues that unblock other issues are more valuable
- **Age third** — older issues have been waiting longer

## Step 4: Suggest top 3

Present the top 3 candidates in a concise format:

```
Here are the top unblocked issues not in flight:

1. **[ID] Title** (priority: high)
   Why: Unblocks 2 other issues. Created 2 weeks ago.

2. **[ID] Title** (priority: high)
   Why: No dependencies, straightforward scope.

3. **[ID] Title** (priority: medium)
   Why: Oldest unblocked issue in the backlog.

Which one do you want to pick up? (or tell me more about any of them)
```

If there are fewer than 3 candidates, show what's available. If there are none,
say so and explain why (everything is either in progress, blocked, or done).

## Step 5: Assign and plan

Once the user picks one:

1. **Assign it** — use `save_issue` to set the assignee to the user and move
   the status to "In Progress" (or the team's equivalent)
2. **Read the full issue** — use `get_issue` to fetch the complete description,
   acceptance criteria, comments, and any linked issues
3. **Start planning** — present the issue details and ask the user how they
   want to approach it. Offer to invoke the `writing-plans` or
   `planning-feature` skill if the issue is complex enough to warrant a plan.
