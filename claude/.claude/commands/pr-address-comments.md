---
title: PR Comment Review Workflow
description: Address PR review comments systematically with triage, implementation, QA, and commit
---

Address all review comments on a PR systematically. Go through each comment one by one, triage, address if needed, QA with Playwright, and commit.

## Input
PR identifier: $ARGUMENTS
- Can be a PR number (e.g., `17484`)
- Can be a branch name (e.g., `feature/my-branch`)
- Can be `local` to use the current branch

## Workflow Steps

### 1. Fetch PR Comments

First, determine the PR number:
- If `$ARGUMENTS` is a number, use it directly
- If `$ARGUMENTS` is "local" or empty, get current branch with `git branch --show-current` and find its PR
- Otherwise, treat as branch name and find PR with `gh pr list --head $ARGUMENTS`

Then fetch all review comments:
```bash
gh api repos/{owner}/{repo}/pulls/{pr_number}/comments --jq '.[] | {author: .user.login, path: .path, line: .line, body: .body, created_at: .created_at}'
```

Also fetch PR conversation comments:
```bash
gh pr view {pr_number} --json comments --jq '.comments[]'
```

### 2. Create Tracking

Create a todo list with ALL comments, grouped by author. Format each todo as:
"Comment N: {file}:{line} - {summary} ({author})"

### 3. Process Each Comment

For EACH comment, in order:

1. **Present the comment** with full context:
   - Author, file path, line number
   - The comment body
   - Read the relevant code section (use `git diff {base_branch} -- {file}` to see what changed)

2. **Ask user how to proceed**:
   - "Address" - implement the change
   - "Skip" - mark complete and continue
   - "Discuss" - need clarification

3. **If addressing**:
   - Make the code change
   - Run linters (rubocop for .rb, eslint for .ts/.tsx/.js)
   - Show the change to user

4. **QA if needed** (for UI/behavior changes):
   - Ask for test credentials if not known
   - Use Playwright to navigate and verify
   - Confirm the fix works

5. **Commit when ready**:
   - After addressing one or more related comments
   - Create descriptive commit message
   - Push if user approves

6. **Update tracking**:
   - Mark todo as completed
   - Move to next comment

### 4. Summary

After all comments are processed, provide a summary:
- Total comments: X
- Addressed: Y
- Skipped: Z
- Commits created: N

## Important Notes

- Always read the file context before suggesting changes
- Group related comments on the same file together
- Run linters after every code change
- Pause for user input after each comment
- Use the TodoWrite tool to track progress throughout
- For QA, prefer using the admin-web-ui skill for login if credentials are needed
