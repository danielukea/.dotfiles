---
name: ralph-plan
description: Converts a design doc or verbose plan into a ralph-compatible plan file with concise checkbox steps. Use when the user says "make this a ralph plan", "convert to ralph plan", "ralph-ify this", or invokes /ralph-plan.
allowed-tools: Read, Write, Edit, Glob, Grep, AskUserQuestion
---

# Ralph Plan Converter

Convert a design doc or verbose plan into a ralph-compatible plan file.

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
2. **Read** CLAUDE.md and CLAUDE.local.md for dev environment context (credentials, commands, conventions)
3. **Ask the user** for any missing context before generating the plan. Use AskUserQuestion to gather:
   - Will this need browser verification? (determines `--with-browser` steps)
   - Any login credentials or URLs ralph should know about?
   - Any specific patterns or reference files to follow?
   - Anything else ralph needs to know that isn't in the design doc?

   Skip questions where the answer is already clear from the source doc or CLAUDE.md. Only ask what's genuinely missing.
4. **Generate** the ralph plan file

## What Ralph Needs

Ralph finds steps by matching `^\s*- \[ \]` (markdown checkboxes). Each iteration spawns a fresh `claude -p` that reads the entire plan, finds the next unchecked item, implements it, and marks it `- [x]`.

A ralph plan is a flat list of checkboxes. Each checkbox is one independently-implementable unit of work.

## Conversion Rules

1. **One checkbox = one implementable chunk.** A chunk is: write code + write/update tests + run tests + run linter. Never split "write code" and "write tests" into separate checkboxes.

2. **Merge "should already pass" steps into the preceding step.** If a cycle says "should already pass from previous cycle," it's not a separate step — fold it into the step that produces the passing behavior.

3. **Be specific in each checkbox.** Reference:
   - File paths to create/modify
   - Method/function names
   - What the tests should cover (list scenarios inline)
   - Ralph gets a fresh context each iteration — it has no memory of previous steps

4. **Keep each checkbox to 1-4 sentences.** Enough for Claude to know exactly what to do, short enough to not bloat the plan file.

5. **Remove things ralph handles itself:**
   - Branch creation (ralph creates `ralph/<plan-name>`)
   - Git commits (ralph commits after each iteration)
   - "Run all tests at the end" steps (ralph runs tests every iteration)

6. **Separate backend and frontend.** Group backend steps first, frontend after. If a plan has E2E/browser steps, put them last with a comment noting they need `--with-browser`. Browser steps use `agent-browser` CLI (not Playwright MCP). Include the specific commands in each E2E checkbox so Claude knows the tool:
   - `agent-browser open <url>` — navigate
   - `agent-browser snapshot -i -c` — get interactive elements with refs (@e1, @e2...)
   - `agent-browser click @e1` — click by ref
   - `agent-browser fill @e3 "text"` — fill input
   - `agent-browser screenshot <path>` — capture screenshot

7. **Preserve context at the top.** Each iteration gets a fresh context with no memory. The header must include everything Claude needs to orient itself:
   - What the feature is (2-3 sentences)
   - Key design decisions and architectural approach
   - Pointer to the design doc if one exists
   - Dev environment info: how to run tests, linters, and the app (read from CLAUDE.md)
   - If there are browser/E2E steps: login credentials and base URL (read from CLAUDE.md or CLAUDE.local.md)
   - Key reference files: list files Claude should read for patterns (e.g., "Mirror pattern from `app/javascript/.../SomeComponent.tsx`")

8. **Order for independence.** Earlier steps should not depend on later ones. Model layer first, then commands/services, then controllers, then frontend.

9. **Group steps into PRs when the source doc has multiple TODOs.** If the source doc describes multiple TODOs or independent features, group steps under `## PR N: <title>` headers. Add `<!-- basecamp: URL -->` or `<!-- linear: ID -->` comments after each header when tracker links are available. Ralph ignores headings and comments — it only matches `- [ ]` checkboxes — so this is backward compatible. Use `/split-ralph` after ralph completes to split the branch into independent PRs.

## Output Format

### Single-PR plan (default)

```markdown
# <Feature Name>

<2-3 sentence context summary>
Design doc: `<path>` (if applicable)

## Context

- **Tests**: `bin/docker/docker-runner bundle exec rspec <spec>`
- **Lint**: `bin/docker/docker-runner bundle exec rubocop -a <file>`
- **App**: http://localhost:3000 — login: <credentials from CLAUDE.md/CLAUDE.local.md>
- **Reference files**: `path/to/pattern.rb`, `path/to/component.tsx`

## Steps

- [ ] <Step description with file paths, method names, and test scenarios>
- [ ] <Next step...>
- [ ] ...

<!-- Steps below require `--with-browser` -->
- [ ] <E2E verification step if applicable>
```

### Multi-PR plan (when source doc has multiple TODOs/features)

```markdown
# <Feature Name>

<2-3 sentence context summary>
Design doc: `<path>` (if applicable)

## Context

- **Tests**: `bin/docker/docker-runner bundle exec rspec <spec>`
- **Lint**: `bin/docker/docker-runner bundle exec rubocop -a <file>`
- **App**: http://localhost:3000 — login: <credentials from CLAUDE.md/CLAUDE.local.md>
- **Base branch**: `<branch name>`
- **Reference files**: `path/to/pattern.rb`, `path/to/component.tsx`

## PR 1: <Title matching TODO>
<!-- basecamp: https://3.basecamp.com/... -->

- [ ] <Step description with file paths, method names, and test scenarios>
- [ ] <Next step...>

## PR 2: <Title matching TODO>
<!-- basecamp: https://3.basecamp.com/... -->

- [ ] <Step description with file paths, method names, and test scenarios>
- [ ] <Next step...>

<!-- Steps below require `--with-browser` -->
- [ ] <E2E verification step if applicable>
```

Ralph processes checkboxes sequentially regardless of headings — `## PR N:` headers and `<!-- -->` comments are metadata for `/split-ralph` to use after ralph completes.

## What NOT To Do

- Don't add steps that aren't in the source doc — convert, don't invent
- Don't include Red/Green/Refactor ceremony — just describe what to build and test
- Don't include architecture diagrams or key-files tables — ralph doesn't need them
- Don't create "verify everything passes" final steps — ralph verifies every iteration
