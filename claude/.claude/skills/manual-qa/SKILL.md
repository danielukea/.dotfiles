---
name: manual-qa
description: Supervised manual QA workflow. Gathers PR context, queries the database for test data, creates a QA.md tracking file, then walks through each test case interactively — generating test artifacts, giving exact manual steps, verifying via DB, and marking progress. Use when user says "manual QA", "QA this branch", or invokes /manual-qa.
allowed-tools: Read, Write, Edit, Grep, Glob, Bash, Task, AskUserQuestion, ToolSearch, mcp__plugin_wealthbox_db__*, mcp__db__*, mcp__psql__*
---

# Manual QA Skill

You are running a **supervised manual QA session**. Your job is to guide the user through testing their PR changes step by step, verifying results via database queries, and tracking everything in a QA.md file.

## Workflow

Follow these steps in order. **Never skip ahead without user confirmation.**

### Step 1: Gather PR Context

Run `gh pr view` on the current branch to get:
- PR title, number, URL
- PR body (especially the "QA steps" or "Test plan" section)
- Base branch

If no PR exists for the current branch, ask the user what they want to QA.

### Step 2: Identify QA Scope

Present the full QA checklist from the PR to the user. Use `AskUserQuestion` to ask which sections/items they want to cover — they may only own a subset of the QA plan.

Record the scoped items for the rest of the session.

### Step 3: Build Data Inventory

Query the database to discover existing test data relevant to the scoped QA items. The specific queries depend on the PR — use the QA steps as a guide for what data to look up.

Use `ToolSearch` to find and load the appropriate database query tools (search for "execute_sql" or "search_objects"), then run queries to gather:
- Relevant records (IDs, names, types, states)
- Relationships between records
- Any preconditions the QA steps assume

Present the data inventory to the user for confirmation before proceeding.

### Step 4: Create QA.md

Create the directory `.local/qa/` if it doesn't exist, then write `.local/qa/QA.md` with:

```markdown
# QA: [PR Title] (#[PR Number])

**Branch:** `[branch name]`
**Base:** `[base branch]`
**PR:** [PR URL]
**Date:** [today's date]

## Data Inventory

[Tables/lists of relevant records discovered in Step 3 — IDs, names, types, relationships, whatever is useful for the QA session]

## Navigation

[Relevant URLs for the QA session — specific pages, admin panels, etc. Use exact URLs with localhost:3000 and tenant IDs.]

## Helpful Commands

[DB queries or console commands the user might want to run during QA]

## QA Checklist

[The scoped TODO items from Step 2, as checkboxes]

- [ ] Test case 1
- [ ] Test case 2
...

## Issues Encountered

[Initially empty — populated during testing]
```

### Step 5: Interactive Test Loop

For each unchecked TODO in `.local/qa/QA.md`:

1. **Prepare**: Generate any needed test artifacts (CSV files, SQL scripts, etc.) and save them to `.local/qa/`. If the test needs specific DB state, tell the user how to set it up or offer to do it via DB queries. Tell the user the exact file path for any generated artifacts.

2. **Instruct**: Give the user **exact manual steps**:
   - Specific URLs (e.g., `http://localhost:3000/1/imports/new`, not "go to the imports page")
   - Specific UI elements to click/fill (e.g., "click the 'Choose File' button", not "upload the file")
   - Specific things to look for (e.g., "you should see a green flash message saying 'Import completed'")

3. **Wait**: Use `AskUserQuestion` to pause and let the user perform the manual steps. Ask them to report what they see.

4. **Verify**: After the user reports back, run database queries to confirm the expected state. Compare actual vs expected. Show the user the verification results.

5. **Record**: Update `.local/qa/QA.md`:
   - Mark the checkbox `[x]` if passed
   - If something went wrong, add details to "Issues Encountered"
   - If **you** made a mistake the user corrected (wrong URL, wrong DB column, wrong assumption, etc.), add it to "Issues Encountered" as a learning — these corrections are valuable for future QA sessions

6. **Next**: Move to the next unchecked item. If there are no more items, go to Step 6.

### Step 6: Summary

When all items are checked (or the user decides to stop):

1. Present a summary: passed / failed / skipped counts
2. Update `.local/qa/QA.md` with the final summary at the top
3. Ask if the user wants to add the results as a comment on the PR

## Rules

- **Never proceed without user confirmation** — this is supervised QA, not automated testing
- **Be specific** — exact file paths, exact URLs with port numbers and tenant IDs, exact element names. Never be vague.
- **Save all artifacts to `.local/qa/`** — CSVs, SQL scripts, screenshots, etc. Always tell the user the exact path.
- **Keep `.local/qa/QA.md` updated** as the single source of truth throughout the session
- **Record friction** — if something doesn't work as expected or the UI is confusing, note it in "Issues Encountered" even if the test technically passes
- **Record your own mistakes** — when the user corrects you (wrong table names, wrong URLs, wrong assumptions), log it in "Issues Encountered". These learnings are valuable.

## Database Verification

- **Use `bin/wealthbox exec`** for any Ruby/Rails commands that query development data.
- **Always write `.rb` script files** for rails runner — never pass inline Ruby via bash. Shell expansion breaks parentheses, quotes, and string interpolation. Write to `.local/qa/<name>.rb` and run with `bin/wealthbox runner .local/qa/<name>.rb`.
- **Database MCP tools may not be available** — Try `ToolSearch` first, but if unavailable, fall back to rails runner scripts immediately. Don't waste time debugging MCP connectivity.
- **Read the model source before querying** — Don't guess column names or method signatures. Skim the model file or run a quick `Model.column_names` check to avoid wrong-field-name errors.

## Test Artifact Guidelines

- **Query the DB BEFORE creating test artifacts** — Discover valid field names, allowed values (enums, select options), relationships, and existing record IDs. Never guess — wrong values produce misleading test failures.
- **Create realistic test artifacts** — CSVs and test data should represent real-world usage: multiple rows, a mix of valid/invalid data, real field names, real values. Don't create minimal stubs with fake column names.
- **One artifact per test case** — Never reuse the same file across tests with different parameters. Name files descriptively to match the specific test intent (e.g., `overwrite_on.csv` and `overwrite_off.csv`, not `test.csv` reused for both).
- **Verify assumptions about the data model** — Before generating artifacts, confirm which fields/associations/options are valid for the specific record type being tested. Query the DB to check.
