---
name: design
description: Style-guide-grounded architectural design for a feature. Dispatches rails-architect and/or react-architect agents (which carry DHH composition and headless-first React patterns), runs a principles review (ETC, Tell-Don't-Ask, SOLID, conventions, testability, least surprise), then hands off to Superpowers (spec + plan + execute) or Plan Mode (start coding now). No code edits. Use whenever the user says "design this", "plan the approach", "how should I build X", "explore approaches", or invokes /design — even for small features, since the principles review and architect lens catch style drift early. **Not for:** bug fixes (just code), broad refactors of existing code (use `arch-analysis`), or initial product scoping (use `scope-project`).
allowed-tools: Read, Grep, Glob, Bash, Agent, WebFetch, AskUserQuestion, Skill, mcp__basecamp__*
---

# Design

Architectural design for a feature, grounded in the project's style guides (DHH Rails composition, headless-first React). The skill is a thin orchestrator: it routes to architect agents that already own the pattern catalogs, then it runs a principles review and hands the chosen approach to an implementation flow.

**No code edits.** This skill explores and decides; it does not write source files. The output is the in-conversation recommendation and the downstream Superpowers spec or Plan Mode plan — not a markdown dump nobody reads.

## Why this shape

The architect agents (`rails-architect`, `react-architect`) are the right home for style-guide expertise — they're already opinionated planners that consult DHH composition patterns and the React pattern skills (`react-composition`, `react-data-fetching`, `react-render-optimization`). This skill doesn't reproduce that knowledge; it routes to the agents that have it.

The skill stays in the main thread because it needs to invoke `Skill` for pattern lookups during the principles review and the handoff (subagents can't always do that). It dispatches architects via the `Agent` tool with `subagent_type` set to the architect name.

## Usage

```bash
/design https://3.basecamp.com/.../todos/123   # Basecamp todo
/design docs/feature-spec.md                    # Local spec file
/design                                         # Describe interactively
```

## Step 1: Gather Context

### Basecamp URL
Extract `project_id` and `todo_id` from `3.basecamp.com/{account}/buckets/{project_id}/todos/{todo_id}`, then:
- `mcp__basecamp__basecamp_get_todo` for the todo
- `mcp__basecamp__basecamp_list_comments` for discussion

### Local file
`Read` the file.

### Interactive
Ask the user to describe the feature.

Summarize what you understand in 3-5 sentences. If the description is unclear or too large for one design pass, say so and ask the user to narrow scope before continuing.

## Step 2: Clarify Ambiguities

Identify gaps that would lead to meaningfully different designs. Use `AskUserQuestion` to batch related questions in **one round**. Focus on:
- Scope boundaries (what's in/out)
- Behavioral ambiguities ("when X, should it Y or Z?")
- Constraints (performance, permissions, compatibility)

Skip this step entirely if the context is already specific. Fold answers into the brief passed to the architect agents in Step 5.

## Step 3: Detect Stack

Scan the feature description and any referenced files. Decide which architect(s) to dispatch.

| Signal | Architect |
|--------|-----------|
| Rails models, controllers, jobs, mailers, views, migrations | `rails-architect` |
| React components, hooks, contexts, frontend routing, data fetching | `react-architect` |
| Both layers touched | dispatch both in parallel |
| Neither — pure infra, scripts, docs | ask the user whether to apply a Rails or React lens, or skip to Step 7 with manual exploration |

When in doubt, lean toward dispatching — the architects are cheap and grounding the design in their pattern catalogs is the whole point.

## Step 4: Pre-load pattern context (optional, main thread only)

For the principles review and the handoff, **you** (the main thread) may want pattern guidance in context. Load via the `Skill` tool only what's relevant to the feature's shape:

| Shape signal | Skill to load |
|--------------|---------------|
| Rails feature (always, for principles review framing) | `rails-composition-dhh` |
| New React component or hook | `wealthbox:headless-component-designer` |
| Composition: hooks, compound, HOC, render props, view/logic split | `react-composition` |
| Caching, dedup, optimistic updates, parallel fetches | `react-data-fetching` |
| Re-render hot spots, memoization | `react-render-optimization` |

Skip this step if nothing in the table fits. Don't load skills speculatively — load only what the feature actually involves. The architect agents will apply their own pattern knowledge inside the subagent; this step is for **your** ability to interpret their output and run the principles review.

## Step 5: Dispatch Architect Agents

Use the `Agent` tool, one call per applicable architect, in parallel. Pass each architect this brief:

> Design **\<feature name\>**.
>
> **Context (from Step 1):** \<3-5 sentence summary\>
>
> **Clarifications (from Step 2):** \<answers, if any\>
>
> Produce:
> 1. **Recommended approach** — concrete, grounded in this codebase. Name actual files and patterns. Apply your style guide.
> 2. **Alternatives considered and rejected** — 1-2 short paragraphs explaining what else you weighed and why you didn't pick it. The reasoning trail, not parallel proposals.
> 3. **Open questions** — anything that, if answered differently, would change your recommendation.
> 4. **Complexity estimate** — rough files touched, layers spanned, size (XS / S / M / L / XL).

The architects' style guides come from their own prompts/skills; you don't need to inject pattern text.

## Step 6: Principles Review

Once architect output(s) return, spawn **one** review agent (`Agent` with `subagent_type=general-purpose`). Pass it the feature context (Steps 1-2) and each architect's full recommendation block.

Prompt:

> Evaluate the recommended approach(es) below against these design principles. You are **not** proposing your own approach — only critiquing.
>
> - **Easy To Change (ETC)** — the overriding principle. When requirements shift, what couples, what isolates, what breaks?
> - **Tell, Don't Ask** — does behavior live with the data it acts on, or does logic leak into callers/controllers?
> - **SOLID** — pragmatic, not dogmatic. Where does each principle land, and is the tradeoff worth it? Don't penalize simplicity.
> - **Codebase conventions** — does the approach follow patterns already established, or invent new ones?
> - **Testability** — does it lead to simple, fast unit tests, or force complex integration tests?
> - **Least surprise** — would another developer immediately understand this? Clever is the enemy of clear.
>
> For each principle, give a one-line rating (Strong / Acceptable / Weak) and the reason. End with:
> - **Verdict:** Sound / Sound with concerns / Needs revision
> - **Concerns:** red flags worth raising before implementation
> - **Suggested tweaks:** small refinements (not a full rewrite)

If two architects' recommendations cover different layers (Rails + React), the reviewer evaluates each layer separately.

## Step 7: Present and Decide

One in-conversation message. Structure:

```markdown
## Feature: <name>

### Context
<3-5 sentences>

### Recommended Approach
<architect output: how it works, files touched, complexity>
(If two architects: two sub-sections, one per layer.)

### Alternatives Considered
<architect's reasoning trail>

### Principles Review
| Principle | Rating | Reason |
|-----------|--------|--------|
| ETC | … | … |
| Tell, Don't Ask | … | … |
| SOLID | … | … |
| Conventions | … | … |
| Testability | … | … |
| Least Surprise | … | … |

**Verdict:** …
**Concerns:** …
**Suggested tweaks:** …

### Open Questions
- …
```

If the principles review flags must-fix concerns, surface them and ask whether to refine the approach (re-dispatch architect with the concerns) or accept and move on.

## Step 8: Handoff

The skill terminates in one of two ways. **Don't write a markdown spec file** — Superpowers writes a proper one if chosen, and Plan Mode is in-memory.

Suggest a handoff from the architect's complexity estimate and the surface area:

| Signal | Suggested handoff |
|--------|-------------------|
| Single file / single layer / surgical | Plan Mode |
| Multiple files, single layer, S/M | Plan Mode (Superpowers also valid) |
| Cross-layer (Rails + React), L/XL, or multi-day | Superpowers |
| Concerns raised in principles review that need iterative refinement | Superpowers |

Ask via `AskUserQuestion`:

> Handoff to:
> - **Superpowers** — full spec + tracked plan + execution checkpoints. Heavier, durable.
> - **Plan Mode** — present the chosen approach as a plan, start coding on approval. Lighter, in-memory.
>
> Recommended: **\<your suggestion\>** because \<one-line reason\>.

### Superpowers path

Invoke `Skill: superpowers:writing-plans` with a primer message:

> Feature: **\<name\>**. Chosen approach: **\<one-paragraph summary\>**. Architect recommendation and principles review are above in this conversation — use them as the spec. Proceed directly to writing the implementation plan.

Design has already done the exploration and decision work that `superpowers:brainstorming` would otherwise do, so we skip straight to the plan-writing phase.

### Plan Mode path

Format the chosen approach as a concise plan (sections: Files to change, Steps, Verification) and call `ExitPlanMode` with that plan content. On approval you exit plan mode and implementation begins in the same conversation.

## Rules

- **No code changes** in this skill — separating the decision from the implementation keeps the handoff to Superpowers / Plan Mode clean and lets the user reject the approach without rolling back commits.
- **No tracked design markdown.** Superpowers writes the spec if needed.
- **Ground everything in the codebase via the architects.** Don't invent patterns the codebase doesn't use.
- **One recommendation per architect, plus alternatives.** Style-guide-driven architects produce a single best answer with the reasoning trail attached — don't ask them to generate parallel proposals.
- **Bias toward simplicity.** When tweaking the recommendation, prefer the less-clever option — the principles review will already flag cleverness as a Least-Surprise risk, so doubling down rarely survives.
- **Stay scoped.** If the request decomposes into multiple independent features, name that and ask which one to design first.
