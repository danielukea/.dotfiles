---
name: push-issues-to-linear
description: Push locally drafted markdown issues to Linear. Reads draft issue files, creates a milestone if needed, and creates each issue with full markdown description and acceptance criteria checkboxes. Use when user says "push to Linear", "create these in Linear", "push issues", "send to Linear", "upload issues", "create tickets", or after drafting and reviewing milestone issues locally.
user-invokeable: true
allowed-tools: Read, Glob, AskUserQuestion, mcp__claude_ai_Linear__list_milestones, mcp__claude_ai_Linear__save_milestone, mcp__claude_ai_Linear__save_issue, mcp__claude_ai_Linear__list_teams, mcp__claude_ai_Linear__list_projects, mcp__claude_ai_Linear__list_issues
---

# Push Issues to Linear

Read locally drafted markdown issue files and create them as Linear issues with the correct project, milestone, team, and status.

## When to Use

- After drafting and reviewing issues locally (natural final step from `/draft-milestone-issues`)
- User says "push to Linear", "create these in Linear", "create tickets"
- User has a `draft_issues/` directory ready to go

## Phase 1: Gather Parameters

If these were established earlier in the session, reuse them. Otherwise ask:

1. **Issues directory** — path to the `draft_issues/{milestone}/` folder
2. **Linear project** — which project to create issues in
3. **Team** — which Linear team
4. **Milestone name** — create if it doesn't exist in the project
5. **Status** — what status to set (usually "Backlog")

Optionally ask about:
6. **Labels** — if the team uses labels, ask which to apply
7. **Priority** — if the team sets priority at creation time

## Phase 1.5: Organizational Structure

Ask about how issues should be organized in Linear:

"Do you want to group issues under parent issues? This works well for Shape Up-style scopes — each parent represents a vertical slice of functionality, and its children are the issues needed to complete that slice. If so, how should they be grouped?"

If the user wants parent issues:
- Review the README's workstream/dependency breakdown for natural groupings
- Propose scope names based on independently demo-able capabilities (Shape Up style)
- Each scope should answer: "What's true when all children are done?" — a demo-able capability
- Confirm the groupings with the user before creating

If the user wants dependencies:
- Read the README's dependency graph
- Plan the `blockedBy` relationships to set after issue creation
- Minimize dependencies — only set them where one issue truly can't be built or tested without another

## Phase 2: Dry Run

Before creating anything, present a confirmation table:

```markdown
I'm about to create these issues in Linear:

| # | Title | Parent (Scope) | Project | Milestone | Status |
|---|-------|----------------|---------|-----------|--------|
| 01 | First Issue | Scope A | {project} | {milestone} | {status} |
| 02 | Second Issue | Scope A | {project} | {milestone} | {status} |
...

**Team:** {team}
**Total issues:** {N} ({M} parent scopes + {N-M} child issues)
**Dependencies:** {D} relationships to set

Proceed?
```

Wait for explicit confirmation. This creates visible issues for the team — do not proceed without a "yes."

## Phase 3: Check/Create Milestone

Use `mcp__claude_ai_Linear__list_milestones` to check if the milestone exists in the project. If not, use `mcp__claude_ai_Linear__save_milestone` to create it.

If milestone creation fails, stop and ask — don't create issues without a milestone.

## Phase 4: Create Issues

### Step 1: Create parent issues (if using scopes)

Create all parent/scope issues first. These are lightweight issues with:
- `title`: the scope name
- `description`: the "what's true when it's done" statement + brief list of children
- Same project, milestone, team, and status as children

Record the parent issue IDs — they're needed for `parentId` on children.

### Step 2: Create child issues

For each markdown file in the directory (sorted by filename number):

1. **Read the file** — extract title (from `# heading`) and body (everything after the title)
2. **Create the issue** using `mcp__claude_ai_Linear__save_issue`:
   - `title`: from the `#` heading
   - `description`: the full markdown body (preserving checkboxes, headers, formatting)
   - `team`: from Phase 1
   - `project`: from Phase 1
   - `milestone`: from Phase 1
   - `state`: from Phase 1
   - `parentId`: the scope's Linear ID (if using parent issues)
   - Plus labels and priority if specified
3. **Record the mapping** — local filename → Linear issue ID and URL

Skip the README.md file and any `deferred-*.md` files — those aren't issues to create.

### Step 3: Set dependencies

After all issues are created, read the README's dependency graph. For each dependency edge, use `save_issue` with `blockedBy` to set the relationship. Batch updates using parallel tool calls.

Minimize dependencies — only set edges where one issue truly cannot be started without another being complete. More parallelism means faster delivery.

### Batching

Create issues in groups of 3-5 using parallel tool calls. Faster than one at a time.

### Description Formatting

Linear uses markdown. The draft files are already in the right format. Preserve:
- `- [ ]` checkboxes — render as interactive todos in Linear
- `##` headers for structure
- Code blocks and backticks
- Bold and bullet lists

Remove the `# Title` line from the description since it becomes the Linear issue title.

## Phase 5: Report

After all issues are created, present the mapping:

```markdown
| # | Title | Linear ID | Parent | URL |
|---|-------|-----------|--------|-----|
| — | Scope A | ABC-1234 | — | https://linear.app/... |
| 01 | First Issue | ABC-1235 | ABC-1234 | https://linear.app/... |
| 02 | Second Issue | ABC-1236 | ABC-1234 | https://linear.app/... |
...

All {N} issues created in {project} under "{milestone}" milestone with status "{status}".
{D} dependency relationships set.
{S} parent scopes created.
```

If any issues failed to create, list the failures separately so the user can retry or fix them.

## Next Step

After issues are pushed, suggest:

> All issues created in Linear. The milestone is ready to work on. You can start picking up issues from the top of the dependency graph.
