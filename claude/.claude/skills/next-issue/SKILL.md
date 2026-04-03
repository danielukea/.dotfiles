---
name: next-issue
description: >
  Suggest the next Linear issue to pick up from a project. Analyzes issue
  dependencies, blockers, milestones, and what's already in progress to
  recommend the highest-value unblocked issue that nobody is working on.
  Assigns it to you and kicks off planning. Use this skill when the user says
  "what should I work on next", "next issue", "pick up next task", "what's
  next in the project", "suggest next issue", "what's unblocked", or wants
  help choosing work from a Linear project. Also use when the user mentions
  a Linear project and seems to be looking for their next task, or provides
  a Linear project URL.
user-invokeable: true
allowed-tools: AskUserQuestion, mcp__claude_ai_Linear__list_projects, mcp__claude_ai_Linear__list_issues, mcp__claude_ai_Linear__get_issue, mcp__claude_ai_Linear__save_issue, mcp__claude_ai_Linear__get_user, mcp__claude_ai_Linear__list_issue_statuses, mcp__claude_ai_Linear__get_project
---

# Next Issue

Pick the best next issue from a Linear project and start planning it together.

## Step 1: Identify the project

If the user provided a project URL, extract the slug from the URL path
(e.g. `ai-inbound-integrations-9d9828456e86`) and use `get_project` with the
slug as the query. Use the project's `name` field for all subsequent
`list_issues` calls — slugs don't reliably work as query values for
`list_issues`.

If the user provided a project name, use it directly. Otherwise, list their
projects with `list_projects` and ask which one.

## Step 2: Get context

Run these in parallel:
- `get_project` with `includeMilestones: true` — get milestones, teams, lead.
  Skip if already fetched in Step 1 with milestones included.
- `get_user` with query `"me"` — need the user's ID and name for assignment
- `list_issues` for the project, filtered to `state: backlog` — unstarted
  backlog issues
- `list_issues` for the project, filtered to `state: unstarted` — issues in
  "Planned" or similar unstarted states (these are a different state type
  from backlog in some teams)
- `list_issues` for the project, filtered to `state: started` — understand
  what's already in flight and who's working on what
- `list_issue_statuses` for the team — understand which statuses map to
  which state types

**Important:** Never fetch all issues unfiltered. Real projects can have 100+
issues and the response will overflow the tool's output limit. Always filter
by state type. If a filtered response is still too large, reduce the `limit`
parameter.

## Step 3: Understand project structure

Before ranking candidates, understand the hierarchy:

1. **Milestones** — if the project has milestones, identify the active one.
   Pick the milestone with the lowest non-zero progress. If all are at 0%,
   pick the one whose name or description suggests it should come first
   (e.g. "Phase 1", "Internal Dogfood" before "Private Alpha"). If still
   ambiguous, use the order they appear in the API response. Filter
   candidates to the active milestone — don't suggest issues from future
   milestones unless the active one is nearly complete (>80%).

2. **Parent/child relationships** — issues with `parentId: null` in a
   hierarchical project are often epics or groups, not actionable work items.
   If most backlog issues have a `parentId`, prefer leaf issues (those with
   a parentId) as candidates. Only suggest parent issues if they have no
   children in the issue list.

3. **In-flight context** — note who is working on what and in which epic.
   This helps suggest work that complements (not duplicates) in-progress
   efforts. Group in-flight issues by epic/parent when presenting them.

## Step 4: Find candidates

Filter the backlog + unstarted issues to find good candidates:

1. **In the active milestone** — or unmilestoned if the project doesn't use
   milestones
2. **Not done** — status type is not "completed" or "canceled"
3. **Not in progress** — status type is "backlog" or "unstarted"
4. **Not assigned** — no current assignee, or assigned to the user already
5. **A leaf issue** — has a `parentId` (in hierarchical projects)
6. **Not blocked** — check if the issue has blocking relations. If an issue
   depends on another issue that isn't done, skip it. Use `get_issue` with
   `includeRelations: true` only if you need to verify specific blockers —
   don't fetch relations for every candidate.

From the candidates, rank by:
- **Unblocking value first** — issues that are parents of or depended on by
  other issues. Count how many other issues become unblocked. Also consider
  whether an issue is foundational for its epic (e.g. data models before UI).
- **Priority second** — urgent > high > medium > low > none. If all issues
  share the same priority (common in new projects), skip this criterion
  entirely rather than ranking arbitrarily.
- **Dependency chain position third** — prefer issues earlier in the
  dependency chain. Look at parent epic ordering and issue numbering as
  signals for intended sequence.
- **Complements in-flight work fourth** — prefer issues that pair well with
  what teammates are already working on (e.g. model layer while someone
  else builds the controller layer).
- **Age fifth** — older issues have been waiting longer

## Step 5: Suggest top 3

Present the top 3 candidates with context about what's already in flight:

```
**Currently in progress:**
- [ID] [Title] ([Assignee])
- [ID] [Title] ([Assignee])

**Top unblocked issues in [Milestone Name]:**

1. **[ID] [Title]** (priority: [level])
   Why: [Specific reason — what it unblocks, how it relates to in-flight work]

2. **[ID] [Title]** (priority: [level])
   Why: [Specific reason]

3. **[ID] [Title]** (priority: [level])
   Why: [Specific reason]

Which one do you want to pick up? (or tell me more about any of them)
```

If there are fewer than 3 candidates, show what's available. If there are none,
say so and explain why (everything is either in progress, blocked, or done).

## Step 6: Assign and plan

Once the user picks one:

1. **Assign it** — use `save_issue` to set the assignee to the user and move
   the status to "In Progress" (or the team's equivalent)
2. **Read the full issue** — use `get_issue` to fetch the complete description,
   acceptance criteria, comments, and any linked issues
3. **Start planning** — present the issue details and ask the user how they
   want to approach it. Offer to invoke the `writing-plans` or
   `planning-feature` skill if the issue is complex enough to warrant a plan.
