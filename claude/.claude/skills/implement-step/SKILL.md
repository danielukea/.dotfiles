---
name: implement-step
description: Implements the next incomplete step from a tracking document (CLEANUP.md, PLAN.md, TODO.md, etc.). Reads the doc, finds the next unfinished item, executes the code changes, runs tests and linters, commits, and updates the doc. Use when the user says "implement next step", "do the next cleanup item", or invokes /implement-step.
allowed-tools: Read, Edit, Write, Grep, Glob, Bash, Task
---

# Implement Step

Execute the next incomplete step from a tracking document.

## Usage

```bash
/implement-step CLEANUP.md        # Implement next step from CLEANUP.md
/implement-step docs/PLAN.md      # Any path to a tracking doc
/implement-step TODO.md step 3    # Target a specific step
```

## Arguments

| Argument | Description |
|----------|-------------|
| First arg (required) | Path to the tracking document |
| `step N` | Optional: target a specific step number instead of the next incomplete one |

## Workflow

1. **Read** the tracking document and identify the next incomplete step (or the specified one)
2. **Explore** the relevant files to understand the change needed
3. **Implement** the actual code changes — do NOT just write a plan or analysis
4. **Run tests** — `bin/docker/docker-runner bundle exec rspec` for Ruby, `bin/docker/docker-runner yarn test` for JS (adjust paths to relevant specs)
5. **Run linters** — `bin/docker/docker-runner bundle exec rubocop -a` on changed Ruby files, `bin/docker/docker-runner yarn tsc --noEmit` for TypeScript
6. **Fix** any test failures or lint errors before proceeding
7. **Update** the tracking document to mark the step as done
8. **Summarize** what was changed and what the next step would be

## Critical Rules

- **Execute, don't plan.** The whole point of this skill is to make code changes, not produce analysis. If you find yourself writing a plan instead of editing files, stop and start editing.
- **One step at a time.** Complete one step fully before moving to the next. Don't batch multiple steps.
- **Stop on ambiguity.** If a step is unclear or requires an architectural decision, explain the options and stop — don't guess.
- **Never commit with failing tests.** If tests fail and you can't fix them, report the failure and leave the step incomplete.
