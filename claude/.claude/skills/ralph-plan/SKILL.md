---
name: ralph-plan
description: Converts a design doc or verbose plan into a ralph-compatible plan file with outcome-driven checkbox steps. Use when the user says "make this a ralph plan", "convert to ralph plan", "ralph-ify this", or invokes /ralph-plan.
allowed-tools: Read, Write, Edit, Glob, Grep, AskUserQuestion
---

# Ralph Plan Converter

Convert a design doc or verbose plan into a ralph-compatible plan file with outcome-driven steps.

## Usage

```bash
/ralph-plan .local/feature-design.md              # Creates .local/feature-design.ralph.md
/ralph-plan .local/feature-design.md output.md    # Creates output.md
```

## Arguments

| Argument | Description |
|----------|-------------|
| First arg (required) | Path to the source plan/design doc |
| Second arg (optional) | Output path. Defaults to `<source-basename>.ralph.md` in the same directory |

**Never overwrite the source file.** The original design doc is preserved as-is.

## Workflow

1. **Read** the source plan/design doc
2. **Read** CLAUDE.md and CLAUDE.local.md for dev environment context (test commands, lint commands, app URLs, credentials, conventions)
3. **Ask the user** for any missing context before generating the plan. Use AskUserQuestion to gather:
   - Which `--prompt` file should ralph use? (e.g. `~/.claude/prompts/wealthbox-tdd.md`)
   - Any specific patterns or reference files to follow?
   - Anything else ralph needs to know that isn't in the design doc?

   Skip questions where the answer is already clear from the source doc or CLAUDE.md. Only ask what's genuinely missing.
4. **Generate** the ralph plan file

## What Ralph Needs

Ralph finds steps by matching `^\s*- \[ \]` (markdown checkboxes). Each iteration spawns a fresh `claude -p` that reads the entire plan, finds the next unchecked item, implements it, and marks it `- [x]`.

A ralph plan is a flat list of checkboxes. Each checkbox is one **outcome** — what should be true when done.

## Conversion Rules

1. **One checkbox = one outcome.** An outcome describes what should be true when the step is complete, not how to get there. Claude decides the implementation.

2. **Steps describe WHAT, not HOW.** Write acceptance criteria, not implementation instructions. Don't dictate file names, method names, or class structures — unless the outcome requires a specific interface (e.g., "The CLI accepts a `--prompt` flag").

3. **Don't split one outcome into multiple steps.** "Write test" + "write code" is one outcome ("Users can be looked up by email"). Don't separate test-writing from implementation — that's the prompt file's job.

4. **Keep each checkbox to 1-3 sentences.** Describe the desired behavior clearly and concisely. Ralph gets a fresh context each iteration — it has no memory of previous steps, but it reads the full plan file including Context and Architecture sections.

5. **Remove things ralph handles itself:**
   - Branch creation (ralph creates `ralph/<plan-name>`)
   - Git commits (ralph commits after each iteration)
   - "Run all tests at the end" steps (ralph verifies every iteration)
   - Verification protocol (that's the `--prompt` file's job)

6. **Separate backend and frontend.** Group backend steps first, frontend after. If a plan has E2E/browser steps, put them last.

7. **Preserve context at the top.** Each iteration gets a fresh context with no memory. The header must include everything Claude needs to orient itself:
   - What the feature is (2-3 sentences)
   - Key design decisions and architectural approach
   - Pointer to the design doc if one exists
   - Dev environment info: test commands, lint commands, app URL (read from CLAUDE.md)
   - If there are browser/E2E steps: login credentials and base URL (read from CLAUDE.md or CLAUDE.local.md)
   - Key reference files: list files Claude should read for patterns

8. **Order for independence.** Earlier steps should not depend on later ones. Model layer first, then commands/services, then controllers, then frontend.

9. **Add an Architecture section for bigger features.** If the feature spans 5+ steps or touches multiple layers, add 3-7 bullets of **constraints and patterns** — not implementation details. This keeps independent iterations aligned:
   - Where things live (directories, namespaces)
   - Patterns to follow (reference existing files)
   - Error handling approach
   - API format or naming conventions

10. **Group steps into PRs when the source doc has multiple TODOs.** If the source doc describes multiple TODOs or independent features, group steps under `## PR N: <title>` headers. Add `<!-- basecamp: URL -->` or `<!-- linear: ID -->` comments after each header when tracker links are available. Ralph ignores headings and comments — it only matches `- [ ]` checkboxes — so this is backward compatible. Use `/split-ralph` after ralph completes to split the branch into independent PRs.

## Discovering Project Commands

Read CLAUDE.md and CLAUDE.local.md (in the project root) to find:
- **Test command**: e.g., `bin/rspec`, `npm test`, `pytest`
- **Lint command**: e.g., `rubocop -a`, `eslint --fix`, `black`
- **App URL**: e.g., `http://localhost:3000`

If CLAUDE.md doesn't have test/lint commands, ask the user via AskUserQuestion.

## Output Format

### Single-PR plan (default)

```markdown
# <Feature Name>

<2-3 sentence context summary>
Design doc: `<path>` (if applicable)

## Context

- **Tests**: <test command from CLAUDE.md>
- **Lint**: <lint command from CLAUDE.md>
- **App**: <app URL> — login: <credentials from CLAUDE.md/CLAUDE.local.md>
- **Reference files**: `path/to/similar/pattern.rb` — follow this pattern

## Architecture (for features with 5+ steps)

- Service objects in `app/services/imports/`, follow pattern in `app/services/exports/`
- All error handling via Result objects, never raise
- API responses follow JSON:API format

## Steps

- [ ] Users can be looked up by email address.
- [ ] The contacts API returns paginated results with cursor-based navigation.
- [ ] Bulk contact import validates email format and deduplicates by email.

- [ ] The import progress page shows a progress bar and completion count.
```

### Multi-PR plan (when source doc has multiple TODOs/features)

```markdown
# <Feature Name>

<2-3 sentence context summary>
Design doc: `<path>` (if applicable)

## Context

- **Tests**: <test command from CLAUDE.md>
- **Lint**: <lint command from CLAUDE.md>
- **App**: <app URL> — login: <credentials from CLAUDE.md/CLAUDE.local.md>
- **Base branch**: `<branch name>`
- **Reference files**: `path/to/pattern.rb`, `path/to/component.tsx`

## PR 1: <Title matching TODO>
<!-- basecamp: https://3.basecamp.com/... -->

- [ ] Contacts can be filtered by custom field values.
- [ ] Filtering by date-range custom fields supports "between", "before", and "after".

## PR 2: <Title matching TODO>
<!-- basecamp: https://3.basecamp.com/... -->

- [ ] The activity feed shows custom field changes with old and new values.
- [ ] Activity entries link back to the contact that was modified.

- [ ] The activity feed renders custom field changes with proper formatting.
```

Steps are pure outcomes — no verification syntax, no file paths, no method names. The `--prompt` file defines what verification to run. The Context section provides project commands.

## What NOT To Do

- Don't write implementation instructions — describe outcomes
- Don't dictate file names, method names, or class structures unless the outcome requires a specific interface
- Don't add verification criteria to steps — that's the `--prompt` file's job
- Don't break one outcome into multiple steps (e.g., "write test" + "write code" are one outcome)
- Don't add steps that aren't in the source doc — convert, don't invent
- Don't include architecture diagrams or key-files tables — ralph doesn't need them
- Don't create "verify everything passes" final steps — ralph verifies every iteration
