---
name: design
description: Architectural design exploration for a feature. Takes a Basecamp todo URL or .md file, explores the codebase, and presents 2-3 competing approaches with tradeoffs. No code changes — exploration only. Use when user says "design this", "explore approaches", or invokes /design.
allowed-tools: Read, Grep, Glob, Task, WebFetch, AskUserQuestion, mcp__basecamp__*
---

# Design

Explore architectural approaches for a feature. **No code changes** — research and decision-making only.

## Usage

```bash
/design https://3.basecamp.com/.../todos/123   # From Basecamp todo
/design docs/feature-spec.md                    # From local file
/design                                         # Describe the feature interactively
```

## Step 1: Gather Context

### From Basecamp URL
Extract `project_id` and `todo_id` from URL pattern: `3.basecamp.com/{account}/buckets/{project_id}/todos/{todo_id}`

```
mcp__basecamp__basecamp_get_todo - Get todo details
mcp__basecamp__basecamp_list_comments - Get discussion/decisions
```

### From .md file
```
Read - Load the file contents
```

### From neither
Ask the user to describe the feature.

Summarize what you understand in 3-5 sentences.

## Step 2: Clarify Ambiguities

Before exploring, identify gaps in the context that would lead to meaningfully different designs. Ask the user about:

- **Scope boundaries** — what's in vs out
- **Behavioral ambiguities** — "when X happens, should it Y or Z?"
- **Constraints** — performance, permissions, compatibility with existing features

Use AskUserQuestion to present questions. Keep it to one round — batch related questions together. Skip this step if the context is already clear and specific.

Fold the answers into the context passed to agents in Step 3.

## Step 3: Parallel Design Exploration

Spawn **3 agents in parallel** (Task tool with subagent_type=Plan), each exploring the codebase independently with a different lens.

All agents receive the same context (feature description from Step 1 + clarifications from Step 2) plus the instruction to explore the codebase, check `docs/decisions/` for ADRs, and propose a concrete approach. Each agent must reference actual files and patterns — no invented abstractions.

### Agent 1: "Simplest Rails-way approach"
> "Propose the simplest, most Rails-conventional approach to this feature. Minimize new abstractions. Prefer existing patterns in the codebase. If it can be done with a model, controller, and view — do that."

### Agent 2: "Maximum reuse approach"
> "Propose an approach that maximizes reuse of existing code — models, concerns, components, shared logic. Look for similar features already built and follow their patterns as closely as possible."

### Agent 3: "Most flexible approach"
> "Propose the most extensible approach — one that handles edge cases gracefully and would be easy to build on later. Only add abstraction where it earns its keep."

Each agent should return:
- **Approach name** (2-3 words)
- **How it works** (brief description)
- **Key files touched** (actual paths)
- **Pros and cons**
- **Complexity** (Low / Medium / High)

## Step 4: Principles Review

After all 3 design agents return, spawn a **4th agent** (Task tool with subagent_type=Plan) to critique all 3 proposals through a design principles lens.

This agent receives all 3 proposals and the feature context. It does NOT propose its own approach — it only evaluates.

> "You are a design principles reviewer. Critique each of these 3 proposals against these principles:
>
> **Easy To Change (ETC)** — the overriding principle. Will this design be easy to change when requirements shift? What's coupled, what's isolated? What breaks if requirements change?
>
> **Tell, Don't Ask** — objects should be told what to do, not queried for state and acted upon externally. Does each approach push behavior into the objects that own the data, or does it leak logic into controllers/callers?
>
> **SOLID** — evaluate pragmatically, not dogmatically. For each approach, call out which SOLID principles it honors or trades off. Is the tradeoff worth it? Don't penalize simplicity for not being abstract enough.
>
> **Codebase conventions** — does this approach follow patterns already established in the codebase, or does it invent new ones? Search for similar features and compare. Inventing new patterns when existing ones work is a red flag.
>
> **Testability** — does this lead to simple, fast unit tests, or does it force complex integration tests? Easy to test usually means easy to change.
>
> **Least surprise** — would another developer on the team immediately understand this approach? Or does it require explanation? Clever is the enemy of clear.
>
> For each approach, give a brief verdict: what it gets right, what concerns you, and a rating (Strong / Acceptable / Weak) for each principle. Then state which approach best balances all six."

The reviewer should return:

```markdown
### Principles Review

| Principle | Approach A | Approach B | Approach C |
|-----------|-----------|-----------|-----------|
| ETC       | [rating + one-line reason] | ... | ... |
| Tell/Ask  | [rating + one-line reason] | ... | ... |
| SOLID     | [rating + one-line reason] | ... | ... |
| Conventions | [rating + one-line reason] | ... | ... |
| Testability | [rating + one-line reason] | ... | ... |
| Least Surprise | [rating + one-line reason] | ... | ... |

**Best balance:** [which approach and why]
**Concerns:** [any red flags across all proposals]
```

## Step 5: Present Results

Collate the 3 agent proposals into a side-by-side comparison:

```markdown
## Feature: [Name]

### Context
[2-3 sentences summarizing the problem and what the agents found in the codebase]

### Approach A: [Agent 1's name]
**Lens:** Simplest Rails-way
**How it works:** [from agent]
**Touches:** [key files]
**Pros:** [from agent]
**Cons:** [from agent]
**Complexity:** Low / Medium / High

### Approach B: [Agent 2's name]
**Lens:** Maximum reuse
**How it works:** [from agent]
**Touches:** [key files]
**Pros:** [from agent]
**Cons:** [from agent]
**Complexity:** Low / Medium / High

### Approach C: [Agent 3's name]
**Lens:** Most flexible
**How it works:** [from agent]
**Touches:** [key files]
**Pros:** [from agent]
**Cons:** [from agent]
**Complexity:** Low / Medium / High

### Principles Review
[Table from Step 4 reviewer]

### Recommendation
[Your synthesis — informed by both the approaches and the principles review. Bias toward simplicity.]

### Open Questions
- [Anything that needs clarification before implementation]
```

If two agents converge on the same approach, note that — convergence is a strong signal.

## Step 6: Decision

Ask the user which approach they prefer, or if they want to explore a different direction.

Once decided, save the decision to `.local/[feature-name].md` in the repo root.

## Rules

- **NO code changes.** Do not edit, write, or create any application code.
- **Bias toward simplicity.** When synthesizing the recommendation, prefer the simplest solution unless complexity is clearly justified.
- **Ground in the codebase.** Every approach must reference actual files and patterns. Don't propose patterns the codebase doesn't use.
- **Be honest about tradeoffs.** Don't oversell any approach.
- **Keep it lightweight.** This is a decision document, not a full spec. Each approach summary should be scannable in under a minute.
- **Note convergence.** If multiple agents independently arrive at the same answer, that's worth calling out.
