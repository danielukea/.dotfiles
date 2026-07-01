---
name: arch-design
description: Style-guide-grounded architectural design for a feature. Fans out general-purpose subagents that load the DHH Rails composition and headless-first React knowledge skills, and runs a principles review against the `design-principles` skill, then continues into implementation however fits — Superpowers, Plan Mode, or just coding. Use whenever the user says "design this", "plan the approach", "how should I build X", "explore approaches", or invokes /arch-design. Scale the process to the feature: a small change may need only a quick principles check, a cross-layer feature warrants fanning out both stacks. **Not for:** bug fixes (just code), broad refactors of existing code (use `arch-analysis`), or initial product scoping (use `brainstorm`).
allowed-tools: Read, Grep, Glob, Bash, Agent, WebFetch, AskUserQuestion, Skill, mcp__basecamp__*
---

# Arch Design

A design pass for a feature, grounded in the project's style guides (DHH Rails
composition, headless-first React). This skill is a thin, **optional-by-part**
orchestrator: it fans out subagents that load the pattern-catalog skills and
checks the result against durable design principles.

**Match the ceremony to the surface area.** The steps below are a toolkit, not a
mandatory pipeline. A one-file change might need only the principles lens; a
cross-layer feature warrants fanning out both stacks and a review. Skip any
step that doesn't earn its keep for the feature in front of you — see the
complexity heuristic in the `design-principles` skill.

## Why this shape

The style-guide knowledge lives in **knowledge skills**, not agents.
`rails-composition-dhh` carries the DHH composition catalog; `react-composition`,
`react-data-fetching`, `react-render-optimization`, and
`wealthbox:headless-component-designer` carry the headless-first React patterns.

This skill doesn't reproduce that knowledge and doesn't need a bespoke architect agent
to hold it. It **fans out `general-purpose` subagents, each told to `Skill`-load the
relevant pattern skill**, then design against it. The knowledge rides in through the
skill; the subagent supplies the isolated context window and lets both stacks run in
parallel. Evaluation criteria come from the `design-principles` skill, not from here.

For a small, single-layer change you understand well, skip the fan-out and design
inline in the main thread — loading the one relevant skill yourself.

## Usage

```bash
/arch-design https://3.basecamp.com/.../todos/123   # Basecamp todo
/arch-design docs/feature-spec.md                    # Local spec file
/arch-design                                         # Describe interactively
```

## The toolkit

Run these in roughly this order, using judgment about which to include.

### Gather context
- **Basecamp URL:** extract `project_id` and `todo_id` from
  `3.basecamp.com/{account}/buckets/{project_id}/todos/{todo_id}`, then
  `mcp__basecamp__basecamp_get_todo` and `mcp__basecamp__basecamp_list_comments`.
- **Local file:** `Read` it.
- **Interactive:** ask the user to describe the feature.

Summarize what you understand in 3-5 sentences. If the description is too large for
one design pass, say so and ask the user to narrow scope first.

### Clarify ambiguities (only if they'd change the design)
Use `AskUserQuestion` to batch related questions in one round — scope boundaries,
behavioral ambiguities, constraints. Skip entirely if the context is already specific.

### Detect stack and decide which skill(s) to fan out

| Signal | Pattern skill to load |
|--------|-----------------------|
| Rails models, controllers, jobs, mailers, views, migrations | `rails-composition-dhh` |
| React components, hooks, contexts, frontend routing | `react-composition` (+ `wealthbox:headless-component-designer` for new component seams) |
| React data fetching, caching, optimistic updates | `react-data-fetching` |
| React memoization / render perf | `react-render-optimization` |
| Both layers touched | fan out one Rails subagent and one React subagent in parallel |
| Neither — pure infra, scripts, docs | apply a lens manually, or skip the fan-out |

Fanning out a subagent per stack is the high-value move for anything non-trivial — it
grounds the design in the real catalog and keeps the main thread clean. For a small,
single-layer change you understand well, it's fine to load the one skill inline and
sketch the approach yourself, then go straight to the principles check.

### Fan out the design subagent(s)
One `Agent` call per applicable stack (`subagent_type=general-purpose`), in parallel.
Brief each one:

> **First, `Skill`-load `<pattern skill for this stack>`** and design against it.
>
> Design **\<feature name\>**.
>
> **Context:** \<3-5 sentence summary\>
> **Clarifications:** \<answers, if any\>
>
> Produce:
> 1. **Recommended approach** — concrete, grounded in this codebase. Name actual files and patterns. Apply the loaded style guide.
> 2. **Alternatives considered and rejected** — the reasoning trail, not parallel proposals.
> 3. **Open questions** — anything that, answered differently, would change the recommendation.
> 4. **Complexity estimate** — files touched, layers spanned, size (XS / S / M / L / XL).

For a small change you're handling inline, skip the fan-out: `Skill`-load the one
relevant pattern skill in the main thread and produce the same four-part output yourself.

### Principles review (scale to the change)
Evaluate the approach against the `design-principles` skill's criteria — ETC,
Tell-Don't-Ask, pragmatic SOLID, conventions, testability, least surprise. For a
substantial or cross-layer design, spawn one review agent (`Agent`,
`subagent_type=general-purpose`) with the feature context and each design subagent's
full recommendation, and have it produce the per-principle ratings table that
`design-principles` defines. For a small change, apply the same lens yourself inline —
no agent needed. Either way, the criteria come from `design-principles`, not from here.

### Present and decide
One in-conversation message:

```markdown
## Feature: <name>
### Context
<3-5 sentences>
### Recommended Approach
<design subagent output: how it works, files touched, complexity>
### Alternatives Considered
<reasoning trail>
### Principles Review
<ratings table from design-principles, or a short inline assessment for small changes>
**Verdict / Concerns / Suggested tweaks**
### Open Questions
- …
```

If the review flags must-fix concerns, surface them and ask whether to refine (re-run
the design subagent with the concerns) or accept and move on.

### Continue into implementation
Pick the continuation that fits — this is a suggestion, not a fork with only two doors:

| Signal | Suggested continuation |
|--------|------------------------|
| Single file / surgical | Just start coding (Plan Mode optional) |
| Multiple files, single layer, S/M | Plan Mode |
| Cross-layer, L/XL, or multi-day | Superpowers (spec + tracked plan) |
| Concerns needing iterative refinement | Superpowers |

Offer the recommended continuation via `AskUserQuestion` when it's a real choice; for an
obvious small change, just proceed. The user is always free to take the design and run
with it themselves.

- **Superpowers path:** invoke `Skill: superpowers:writing-plans` with a primer — feature
  name, chosen approach in a paragraph, and a pointer to the design recommendation and
  principles review already in the conversation. Skip `superpowers:brainstorming`; the
  exploration is done.
- **Plan Mode path:** format the chosen approach (Files to change, Steps, Verification) and
  call `ExitPlanMode`.

## Notes (not hard rules)

- **This is a design pass, so it usually doesn't edit source files** — separating the
  decision from implementation lets the user reject the approach cleanly. But if a quick
  exploratory sketch or spike is the fastest way to answer a design question, that's a
  legitimate part of designing; don't contort around the "no edits" idea.
- **Don't write a tracked design-markdown dump** nobody reads. Superpowers writes a proper
  spec if that path is chosen; Plan Mode is in-memory.
- **Ground everything in the codebase.** Don't invent patterns the codebase doesn't use —
  that's what the pattern skills and the conventions principle are for.
- **One recommendation per stack, plus the reasoning trail** — not parallel proposals.
- **Bias toward simplicity.** Least surprise beats clever; the principles review will flag
  cleverness anyway.
- **Stay scoped.** If the request is really several features, name that and ask which to
  design first.
