---
name: split-ralph
description: Split a completed ralph branch into independent PRs, one per PR group defined in the plan file. Use when the user says "split ralph", "split into PRs", "create PRs from ralph", or invokes /split-ralph.
allowed-tools: Read, Write, Edit, Glob, Grep, Bash, AskUserQuestion, Task
---

# Split Ralph Branch into Independent PRs

Split a completed ralph branch into independent PRs, one per PR group defined in the plan file.

## Usage

```bash
/split-ralph <plan-file>              # Splits using origin/master as base
/split-ralph <plan-file> <base-branch> # Splits using specified base branch
```

## Arguments

| Argument | Description |
|----------|-------------|
| First arg (required) | Path to the ralph plan file |
| Second arg (optional) | Base branch to cherry-pick onto. Defaults to `origin/master` |

## Workflow

### Phase 1: Parse the Plan File

1. **Read** the plan file
2. **Find PR groups** by scanning for `## PR N: <title>` headers
   - Extract the title from each header
   - Extract `<!-- basecamp: URL -->` or `<!-- linear: ID -->` comments immediately following each header
   - Collect all `- [x]` checkboxes under each header — these are the completed steps belonging to that PR group
3. **If no `## PR N:` headers found**: list all completed iterations and ask the user to group them interactively via `AskUserQuestion`

### Phase 2: Map Commits to PR Groups

1. **Read git log** on the current ralph branch:
   ```bash
   git log --oneline origin/<base>..HEAD
   ```
2. **Map ralph iteration commits** to PR groups:
   - Ralph commits follow the pattern `ralph: iteration N` — iteration N maps to the Nth `- [x]` checkbox across all groups (counted sequentially from top of file)
   - Example: if PR 1 has 3 steps and PR 2 has 2 steps, iterations 1-3 belong to PR 1 and iterations 4-5 belong to PR 2
3. **Identify review fix commits**: any commits after the last ralph iteration, or commits that don't match the `ralph: iteration N` pattern, should be presented to the user for manual assignment
4. **Read the `## Context` section** from the plan file — extract test commands, base branch, app URL, and any other metadata needed for PR creation

### Phase 3: Confirm with User

**Before any git operations**, present the mapping to the user via `AskUserQuestion`:

```
I've mapped the ralph branch to N PRs:

PR 1: <title>
  Commits: <iteration 1 hash>, <iteration 2 hash>, ...
  Tracker: <basecamp/linear link>

PR 2: <title>
  Commits: <iteration 4 hash>, <iteration 5 hash>, ...
  Tracker: <basecamp/linear link>

Unassigned commits (if any):
  <hash> <message> — needs manual assignment

Does this mapping look correct?
```

Wait for user confirmation before proceeding. If the user wants changes, adjust the mapping accordingly.

### Phase 4: Create PR Branches (Sequential)

For each PR group, in order:

1. **Create branch** from base:
   ```bash
   git checkout origin/<base> -b <branch-name>
   ```
   Branch naming: use a slugified version of the PR title (e.g., `add-relationship-labels` for "Add Relationship Labels")

2. **Cherry-pick commits** for this group:
   ```bash
   git cherry-pick --no-commit <commit1> <commit2> ...
   ```

3. **Resolve conflicts** using the conflict resolution strategy below

4. **Squash into one commit**:
   ```bash
   git commit -m "<PR title>

   <brief summary of what this PR does based on the plan steps>"
   ```

5. **Run tests** using the test command from the plan's `## Context` section. If tests fail, report the failure but continue to the next PR group.

6. **Push and create draft PR**:
   ```bash
   git push -u origin <branch-name>
   ```
   Then create the PR using `gh pr create`:
   - Read `.github/PULL_REQUEST_TEMPLATE.md` for the PR template
   - Fill out the template based on the plan context and diff
   - Include the basecamp/linear link in the PR description
   - Create as a draft PR (`--draft`)
   - Set the base branch appropriately

7. **Return to the ralph branch** before starting the next PR group:
   ```bash
   git checkout <ralph-branch>
   ```

### Phase 5: Report Summary

After all PR groups are processed, report:

```
Split complete! Created N PRs:

1. <PR title> — <PR URL>
   Tests: PASSED / FAILED (with details)
   Tracker: <link>

2. <PR title> — <PR URL>
   Tests: PASSED / FAILED (with details)
   Tracker: <link>

Manual steps needed:
- [ ] Review each draft PR
- [ ] Mark PRs as ready when reviewed
- [ ] <any other manual steps based on test failures or unresolved conflicts>
```

## Conflict Resolution Strategy

When cherry-picking, conflicts will occur. Resolve them in this priority order:

### 1. Plan File Conflicts
Every ralph iteration modifies the plan file. **Always auto-resolve by removing the plan file** (whatever `<plan>.md` was passed as the first argument):
```bash
git rm <plan>.md 2>/dev/null
```
The plan file should not be in any PR.

### 2. Content Conflicts — AI Resolution
For actual code conflicts:
1. Read the conflicted file (look for `<<<<<<<`, `=======`, `>>>>>>>` markers)
2. Read the plan file to understand what each PR group's steps do
3. Keep only the code that belongs to the **current PR group** — code from other groups should be discarded (use the base version for those sections)
4. Write the resolved file

### 3. Ambiguous Conflicts — Ask User
If the conflict cannot be confidently resolved (code is intertwined between groups, or the plan doesn't clearly describe ownership):
1. Show the conflict to the user via `AskUserQuestion`
2. Include the conflicting sections and which PR groups might own them
3. Apply the user's resolution

## Branch Naming Convention

Generate branch names from PR titles:
- Lowercase, hyphen-separated
- Remove articles (a, an, the) and filler words
- Max 50 characters
- Example: "Add Custom Relationship Labels" → `add-custom-relationship-labels`

## PR Description Generation

For each PR, generate the description by:
1. Reading `.github/PULL_REQUEST_TEMPLATE.md`
2. Filling in each section:
   - **Summary**: derived from the plan steps in this PR group
   - **Changes**: derived from the actual diff
   - **Testing**: from the plan's `## Context` test commands
   - **Links**: basecamp/linear URLs from plan file comments
3. Using the filled template as the `--body` argument

## What NOT To Do

- Don't create PRs that depend on each other — each branches independently from base
- Don't include the plan file in any PR
- Don't force-push or rewrite history on the ralph branch
- Don't proceed past Phase 3 without user confirmation
- Don't silently skip failed cherry-picks — report them clearly
