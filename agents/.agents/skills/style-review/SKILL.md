---
name: style-review
description: Composition and pattern review of a diff, branch, or PR against the codebase's style guides. Use on "style review", "review this branch", "refactor suggestions", or "is this DHH-style". Not for: bugs or security — use `code-review`.
allowed-tools: Read, Grep, Glob, Bash, Agent, AskUserQuestion, Skill
---

# Style Review

Composition/pattern review of a diff. The skill orchestrates: gather the diff, fan out a subagent per stack that loads the right pattern skill and reviews against it, run a principles review against the diff, and present severity-tagged findings with concrete refactors.

**No code edits.** This skill reviews and recommends; it does not apply changes. For broader review (bugs, security, perf), point the user at `code-review` or `wealthbox:code-review`.

## Why this shape

The style guides live in **knowledge skills** — `rails-composition-dhh` for Rails; `react-composition`, `react-data-fetching`, `react-render-optimization`, and `wealthbox:headless-component-designer` for React. This skill fans out a `general-purpose` subagent per applicable stack, each told to `Skill`-load its pattern skill and review the diff against it in its own context window (both stacks in parallel), then adds a principles pass on the diff, then presents the unified findings. The knowledge rides in via `Skill`; the subagent supplies the isolated context — no bespoke architect agent required.

## Usage

```bash
/style-review                       # current branch vs main
/style-review <branch>              # branch vs main
/style-review <pr-url-or-number>    # PR diff via gh
```

## Step 1: Gather the Diff

Resolve the diff source:

| Input | Command |
|-------|---------|
| (none) | `git diff $(git merge-base HEAD main)...HEAD` (fall back to `master` if `main` missing) |
| branch name | `git diff $(git merge-base HEAD <branch>)...HEAD` |
| PR url or number | `gh pr diff <id>` |

Also capture file list (`git diff --name-only ...`) and a summary line: files changed, additions/deletions.

If the diff is empty, say so and stop.

## Step 2: Detect Stack

Use the changed-file list to decide which pattern skill(s) to fan out.

| File signal | Pattern skill |
|-------------|---------------|
| `app/models/`, `app/controllers/`, `app/jobs/`, `app/mailers/`, `db/migrate/`, `*.rb` | `rails-composition-dhh` |
| `.tsx`, `.ts`, `.jsx`, frontend `components/`, `hooks/`, `contexts/` | `react-composition` (+ `react-data-fetching` / `react-render-optimization` / `wealthbox:headless-component-designer` as the diff warrants) |
| Both | fan out one Rails subagent and one React subagent in parallel |
| `db/migrate/` only, no `app/` changes | flag as out of scope for style review and stop |
| Neither (pure config, infra, docs) | tell the user there's nothing for the style-fit lens to review and stop |

## Step 3: Pick the Skill Each Subagent Loads

Rails is one skill; React is a small menu — pick the React skill(s) that match the diff. Each fanned-out subagent `Skill`-loads exactly what its stack needs (one Rails skill, and/or one-to-two React skills).

Reference table:

| Diff shape | Skill to load |
|------------|---------------|
| Rails diff (always, for the DHH composition lens) | `rails-composition-dhh` |
| New or substantially changed React components/hooks | `wealthbox:headless-component-designer` |
| Composition: hooks, compound, HOC, render props | `react-composition` |
| Data fetching, caching, optimistic updates | `react-data-fetching` |
| Memoization, render perf | `react-render-optimization` |

## Step 4: Fan Out the Review Subagent(s)

Use `Agent`, one call per applicable stack (`subagent_type=general-purpose`), in parallel. Brief each one:

> **First, `Skill`-load `<pattern skill(s) for this stack>`** — this carries the style guide you review against. Then:
>
> **Review this diff for style/composition fit.**
>
> **Diff:**
> ```
> <full diff output, or a `gh pr diff` capture>
> ```
>
> **Changed files:**
> <list>
>
> **Your job:** evaluate the diff against the loaded style guide (DHH composition for Rails, headless-first React for frontend).
>
> Produce:
> 1. **Findings** — each one tagged severity (`must-fix` / `suggestion` / `nit`), with:
>    - `file:line` reference
>    - the pattern violated or the pattern being misapplied
>    - a concrete refactor (the shape of the fix, not the full code)
> 2. **What the diff gets right** — patterns honored, good calls worth keeping. Brief.
> 3. **Open questions for the author** — things you'd want to ask before recommending a final direction.

**Example finding (must-fix):**
- **app/controllers/articles_controller.rb:42** — thin-controller violation — the publish + notify + log sequence belongs on `Article#publish!`; controller should call it and render. Per DHH thin-controller pattern.

**Small diffs:** for a one-file, single-stack diff you can evaluate directly, skip the fan-out — `Skill`-load the one relevant pattern skill in the main thread and produce the same output yourself.

**Large diffs:** if the diff exceeds ~1000 changed lines or ~20 files, ask the user whether to (a) review the highest-churn file group first, (b) review by directory, or (c) proceed against the full diff with the subagent summarizing rather than line-citing. Don't truncate silently.

## Step 5: Principles Review (against the diff)

Spawn **one** review agent (Agent with `subagent_type=general-purpose`). Pass it:
- The diff (or summary if huge)
- Each review subagent's findings

Prompt:

> `Skill`-load `code-design-principles` and evaluate the **diff** against its lenses. You are
> reviewing the changes themselves, not proposing alternatives — for each lens, ask whether
> the diff leaves this code easier or harder to change than before.
>
> Use the ratings table and closing rules from that skill's `review-format.md` reference,
> with the **diff** verdict scale: Ship / Ship with tweaks / Refactor before shipping. Rate
> only the lenses that bear on this diff, and end with the **top 3 concerns** (or fewer if
> there are fewer).

## Step 6: Present Findings

One in-conversation message. Structure:

```markdown
## Style Review: <branch or PR>

**Files:** <N changed>, +<A> / -<D>
**Stack:** Rails / React / Full-stack

### Must-fix
- **<file:line>** — <pattern> — <refactor>
- …

### Suggestions
- **<file:line>** — <pattern> — <refactor>
- …

### Nits
- **<file:line>** — <pattern> — <refactor>
- …

### What this gets right
- …

### Principles Review
<ratings table per code-design-principles' review-format.md — only the lenses that bear on this diff>

**Verdict:** Ship / Ship with tweaks / Refactor before shipping
**Top concerns:** …

### Open questions for the author
- …
```

Group findings by file when there are many in the same file. Sort within each severity by file path.

## Step 7: Terminate

This skill is **terminal**. Don't apply refactors automatically. End with one of:

- **No must-fix items:** "Looks good to ship. \<N\> suggestions and \<M\> nits above if you want to address them."
- **Must-fix items present:** "Recommend refactoring before shipping. Let me know how you want to proceed — I can hand off to `/arch-design`, start edits if you confirm scope, or just leave the report here."

Don't auto-invoke `/arch-design` or any implementation flow — leave that to the user.

## Rules

- **Pattern fit only.** Don't flag bugs, security, or performance unless they're style-driven (e.g., a leaky abstraction caused by misplaced logic). Point to `code-review` for the broader pass.
- **No code edits in this skill.** Findings are recommendations, not patches.
- **Cite specific lines and patterns.** "This is non-Rails-y" is useless; "controllers/articles#publish does the work itself; should be `article.publish!` on the model per DHH thin-controller pattern" is useful.
- **Use the loaded skills' style guides, not your own.** Don't invent patterns.
- **Stay focused.** If the diff has no Rails or React content, say so and stop.
- **Severity discipline:**
  - `must-fix` — pattern violation that meaningfully hurts ETC, testability, or convention (e.g., service object where model method fits, JSX-first component, prop-drilling instead of context).
  - `suggestion` — better pattern available but the current code is workable.
  - `nit` — small cleanup; safe to ignore.
