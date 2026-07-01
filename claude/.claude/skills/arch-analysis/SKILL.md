---
name: arch-analysis
description: >
  Deep architectural analysis of any codebase using parallel exploration agents.
  Each agent examines a different dimension (coupling, complexity, churn, state
  management, duplication, error handling, structure, extensibility, variation
  points, contract surface, vertical slicing) and produces structured findings
  that get synthesized into a prioritized improvement report grounded in
  connascence and ETC ("Easier to Change"). Use this skill whenever the user
  says "analyze architecture", "find architectural improvements", "codebase
  analysis", "what should we refactor", "tech debt audit", "code health check",
  "architectural review", "we have a lot of tech debt", "is this extensible",
  "how hard will this be to change", or asks about structural problems,
  hotspots, coupling issues, or extensibility across the whole codebase or a
  scoped feature. Also use when the user wants to understand the overall
  shape of an unfamiliar codebase before extending it. This is different from
  code-review (which examines a diff) — this examines the entire codebase as
  it exists today.
user-invokeable: true
allowed-tools: Read, Glob, Grep, Bash, Write, Edit, Agent, AskUserQuestion
---

# Architectural Analysis

Dispatch 10 parallel agents to examine a codebase from orthogonal angles, then
synthesize findings into a prioritized report grounded in **connascence**
(measurement) and **vertical slicing** (technique), with **ETC — Easier to
Change** as the north star.

**Not this skill:** Reviewing a PR → `code-review`. Exploring one feature →
`explore`. Planning a known feature → `writing-plans`.

---

## North star: ETC — Easier to Change

The skill's job is to surface what is hard to change, and why. Every finding
answers some version of *"if requirement X changes, what would break?"*

The organizing principle, borrowed from *The Pragmatic Programmer* (20th
anniversary edition), is **ETC — Easier to Change**: when two designs achieve
the same behavior, the one that leaves more options open wins.

- **Connascence** (`references/connascence.md`) is how we *measure* ETC —
  every extensibility-focused finding tags `{form, locality, degree}`.
- **Vertical slicing** (`references/vertical-slicing.md`) is how we *achieve*
  ETC — keep high-strength connascence (CoA, CoE, CoTime, CoV, CoI) inside
  one slice so changes don't ripple.
- **Pragmatic principles** (`references/pragmatic-principles.md`) give every
  lens a shared vocabulary so the report reads with one voice.

---

## Phase 0: Context Gathering

### Detect tech stack

Check the project root for manifest files and infer the stack:

| Marker | Stack |
|--------|-------|
| `Cargo.toml` | Rust |
| `Gemfile` | Ruby / Rails |
| `package.json` | JS/TS — inspect for React, Vue, Angular, Next, Remix, Express |
| `go.mod` | Go |
| `pyproject.toml`, `requirements.txt` | Python |
| `mix.exs` | Elixir |
| `build.gradle`, `pom.xml` | Java / Kotlin |
| `*.sln`, `*.csproj` | C# / .NET |

Also read CLAUDE.md, README, and directory structure for architectural context.
Polyglot repos get multiple stack tags. For each detected stack, agents will
load the matching `references/stacks/{stack}.md` adapter. If both Rails and
React are present, also load `references/stacks/cross-stack.md`.

### Determine scope

Ask the user (skip if a path was passed as argument):

> Should the analysis cover the whole repo (default), a specific subdirectory,
> or a named feature/module?

`AskUserQuestion` with options *whole repo* / *a subdirectory* / *a named
module*. Pass the chosen scope to every agent. Extensibility findings are
most actionable when scoped to "the part I'm about to extend."

### Check available CLI tools

```bash
for tool in scc ast-grep dep-tree jscpd semgrep knip madge depcruise radon \
            rubocop brakeman vulture mergestat skunk reek flog flay packwerk \
            fta-cli ts-prune type-coverage gocyclo staticcheck cargo-tarpaulin; do
  command -v "$tool" &>/dev/null && echo "available: $tool" || echo "missing: $tool"
done
```

Agents adapt to what's installed. Everything works with just grep/glob/read —
CLI tools add richer quantitative data.

If the user wants to install tools first, see `references/tools.md` for the
recommended install list organized by lens and language.

### Estimate codebase size

```bash
find . -type f \( -name '*.rb' -o -name '*.py' -o -name '*.ts' -o -name '*.tsx' \
  -o -name '*.js' -o -name '*.jsx' -o -name '*.rs' -o -name '*.go' \
  -o -name '*.java' -o -name '*.kt' -o -name '*.ex' -o -name '*.exs' \
  -o -name '*.cs' \) | wc -l
git rev-list --count HEAD 2>/dev/null || echo "0"
```

**Adaptive dispatch rules:**
- < 20 source files → skip Duplication agent (not enough surface area)
- < 50 git commits → skip churn portion of Complexity & Churn agent; skip the
  `git log`-driven half of Extensibility's history simulation
- Monorepo with distinct packages → tell agents to analyze per-package
- Scope = subdirectory → agents only analyze inside the scope, but treat
  imports *out* of the scope as connascence-at-distance findings

---

## Phase 1: Parallel Exploration (10 agents)

Read each agent's prompt from `references/<lens>.md` before dispatching.
Dispatch all 10 simultaneously via the Agent tool. Each agent receives:

- Detected tech stack(s)
- Scope (whole repo / subdir / module)
- Available CLI tools list
- Project root path
- Its lens-specific prompt from `references/`
- Reference to load `references/stacks/{stack}.md` (and `cross-stack.md` if
  polyglot Rails+React)
- Reference to `references/connascence.md` for tagging findings
- Reference to `references/pragmatic-principles.md` for severity citations

| # | Lens | Prompt | What it finds |
|---|------|--------|---------------|
| 1 | **Coupling** | `coupling.md` | Circular deps, layer violations, fan-in/out, missing boundaries |
| 2 | **Complexity & Churn** | `complexity-churn.md` | Hotspots — complex × untested × churning (StinkScore harness) |
| 3 | **State & Data Flow** | `state.md` | Persistence patterns, race conditions, transformation chains |
| 4 | **Duplication & Patterns** | `duplication.md` | Knowledge-duplication (not just textual), missing abstractions |
| 5 | **Error Handling & Resilience** | `errors.md` | Silent failures, inconsistent strategies, resource leaks |
| 6 | **Structure & Conventions** | `structure.md` | File organization, naming drift, dead code, public surface |
| 7 | **Extensibility** ⭐ | `extensibility.md` | Open/Closed adherence, change-impact simulations, missing seams |
| 8 | **Variation Points** ⭐ | `variation-points.md` | Clean seams (strategy/registry/flag) vs dirty (case-on-type) |
| 9 | **Contract Surface** ⭐ | `contract-surface.md` | Public APIs — documented? validated? versioned? owned? |
| 10 | **Vertical Slicing** ⭐ | `vertical-slicing.md` | Slice topology, dependency direction, concern-direction discipline |

⭐ = extensibility-focused lenses (the new four).

**Why orthogonal lenses?** A single agent exploring everything hits context
limits and loses focus. These lenses surface different categories of issues —
coupling analysis never finds churn problems, churn analysis never catches
extensibility seams, and an extensibility lens never catches a swallowed
exception. Running them in parallel cuts wall time dramatically.

### Agent output format

Every agent structures its response with the exact field names below.

**Hard limits:**
- **Max 6 findings** per agent. If you have more, drop the lowest-severity ones.
- **Max ~150 words per finding** (Finding through Direction inclusive).
- **Total ≤ 800 words.**

If you can't fit a finding in 150 words, you're explaining instead of evidencing
— shorten until each line earns its place.

```
### What's Working Well
- [observation] — [evidence: file paths, patterns]

### Adapter patterns applied
- [pattern name from references/stacks/{stack}.md] — [where you used it]
- (at least one per agent that loaded a stack adapter)

### Findings
For each finding, use these exact field names in this order:

- **Finding**: One-line summary
- **Connascence**: {Form} ({strength}) at {locality} (×{mult}), degree {n} → {score} ({bucket})
  (omit only when the finding genuinely has no inter-element coupling
   component — e.g., a swallowed exception with no shared state)
- **Severity**: low | medium | high | critical
  (must match the bucket from Connascence when present; otherwise use
   judgment)
- **Trend** *(optional)*: rising | stable | falling — only if the formula
  score understates the risk because the area is actively growing
  (more consumers added recently, more variants likely soon). Use this
  field instead of overriding the Severity bucket. Cite git evidence.
- **Pragmatic principle**: {principle from references/pragmatic-principles.md}
  — {one-line justification}
- **Evidence**: file:line references, metrics, CLI tool output
- **Impact**: What breaks or degrades if unaddressed
- **Direction**: Concrete next step (not a full plan). For cross-slice
  findings, name both remedies: (a) collapse to one slice or (b) define a
  contract.

### Metrics
- [metric]: [value] — [interpretation]
  (only if CLI tools produced quantitative data)
```

**Use `Direction`, not `Suggestion`.** **Severity bucket must match the
Connascence-formula bucket** when present — don't free-text it.

---

## Phase 2: Synthesis

After all agents return, run these steps **in order**. They are deterministic
— don't skip or re-order.

### 2.1 Build the finding index

For every finding from every agent, extract a normalized key:

```
key = sort(unique(file_paths_in_evidence))[0..3]    # up to 3 paths
```

If the finding cites no specific files (e.g., "no schema validation
anywhere"), key it on the lens name + first-noun-phrase of the title.

Store: `{ key, lens, severity_score, severity_bucket, connascence, finding_title }`.

### 2.2 Detect convergence

Group findings by key. **Any group with ≥ 2 distinct lenses is a
convergence.** Convergence overrides individual severity:

- Single high finding: keep as high.
- Two-lens medium convergence: promote to high.
- Three-lens convergence at any severity: promote to critical.

Cite the convergent lenses inline (`Flagged by: Coupling + Vertical Slicing`).

### 2.3 Compute the Extensibility Hotspot Table

For each top-10 hotspot from the Complexity & Churn agent, overlay the
highest-strength connascence form found in that file by *any* other lens:

```
ExtensibilityHazard(file) = ExtensibilityScore(file) × max_connascence_strength_in(file)
```

This is the headline metric.

### 2.4 Pull the slice map

From the Vertical Slicing agent, render its slice map verbatim. Don't rebuild
it — that lens owns the analysis. Just verify it includes: slices, what
each owns, dependency direction, cycles/back-edges.

### 2.5 Apply the two-remedy framing

For every finding tagged `across-slices` or `across-services`, you (the
synthesizer, not the originating agent) must add a `Remedies:` line with
both options:

```
**Remedies**:
  (a) **Collapse**: move the colliding sites into one slice — converts
      long-distance connascence to short-distance.
  (b) **Contract**: define an explicit boundary (schema, port, ACL) between
      the slices — keeps them separate but typed.
```

Pick a recommended option based on whether the slices have independent
reasons to exist (favor contract) or arose accidentally (favor collapse).

### 2.6 Deduplicate and categorize into:
   - Architecture & Coupling
   - Code Health & Complexity
   - Data Integrity & State
   - Reliability & Error Handling
   - Maintainability & Conventions
   - **Extensibility** (Open/Closed, missing seams, change-impact)
   - **Slice Topology** (vertical slicing findings)
   - **Contract Surface** (cross-stack, public APIs)

### 2.7 Produce the report:

```markdown
# Architectural Analysis: {project}

## Stack & Scope
{detected stack, frameworks, scope, file count, commit count}

## What's Working Well
{consolidated positives — important for calibrating the findings}

## Slice Map
{table or text diagram of slices and dependency direction}

## Extensibility Hotspot Table
| File | Complexity | Coverage | Churn | Max Connascence | Hazard |
|------|-----------|----------|-------|-----------------|--------|
| ...  | ...       | ...      | ...   | CoA cross-slice | high   |

## Top Findings (ranked by impact)

### 1. {Title}
**Category**: ...  |  **Severity**: high/medium/low
**Flagged by**: {agent 1, agent 3} ← convergence signal
**Connascence**: {form} at {locality}, degree {n}
**Pragmatic principle**: {principle}
**Evidence**: {file paths, metrics, tool output}
**Impact**: {consequence of inaction}
**Direction**: {concrete next step — see Context7 References}
{If cross-slice: offer both remedies — collapse vs. contract.}

### 2. ...
(top 5–8 findings)

## Change-Impact Simulations
{from Extensibility agent — 3–5 plausible future requirements ranked by
total change cost (file count × max connascence strength touched)}

## Lower Priority
{remaining findings, briefly grouped by category}

## Metrics Summary
{quantitative data from CLI tools, if any}
```

---

## Phase 3: Interactive Prioritization

Present the report and ask:

> "Here are the top findings ranked by impact. Which 2–3 would you like to
> focus on? I can generate an implementation plan for your selections."

The skill surfaces evidence; the human decides what matters given project
phase, team capacity, and upcoming work.

---

## Phase 4: Plan Generation (optional)

If the user picks items and says "plan it":

1. Invoke `writing-plans` for the selected improvements — use the Context7
   References section to ground plan steps in established refactoring patterns
2. After the plan is written, invoke `code-review` on the plan to catch
   convention violations early

For specific finding types, suggest chaining into a sibling skill instead:

| Finding type | Chain into |
|--------------|-----------|
| Missing React headless seam | `wealthbox:headless-component-designer` |
| Rails service/concern refactor | `rails-composition-dhh` skill |
| New feature on top of unstable seam | `planning-feature` |
| Whole-system follow-up | `roadmap` |

Discovery and execution stay separate.

---

## Limitations

- **Periodic use** — at milestones or before a major extension, not daily.
  Ten agents are expensive.
- **No auto-refactor** — output is a report (and optionally a plan).
- **Git history helps** — churn and change-impact analyses need commits.
  New repos benefit less.
- **CLI tools are optional** — enrich but don't gate the analysis. Skunk +
  Packwerk + fta-cli + ESLint boundaries dramatically sharpen findings when
  available.

---

## Context7 References for Refactoring Strategies

When generating the **Direction** for findings or building Phase 4 plans, use
context7 to fetch current documentation on relevant refactoring patterns. This
grounds suggestions in established techniques with code examples.

### Available libraries

| Library ID | Content | Use for |
|------------|---------|---------|
| `/websites/refactoring_guru` | Extensive refactoring techniques catalog + code smells | Tactical refactoring suggestions (Extract Method, Move Function, etc.) |
| `/websites/refactoring_guru_design-patterns` | GoF design patterns with multi-language examples | Adapter, Facade, Strategy patterns for ACL, Strangler Fig, Branch by Abstraction |
| `/websites/sourcemaking_refactoring` | Code smells + refactoring techniques with interactive examples | Alternative explanations when refactoring_guru results aren't sufficient |
| `/websites/refactoring_guru_smells` | Code smell definitions and categories | Naming specific smells when citing evidence |
| `/sairyss/domain-driven-hexagon` | DDD + Hexagonal Architecture patterns | Anti-Corruption Layer, bounded contexts, enforcing architectural boundaries |

### When to query

- **Coupling findings** → query design patterns (Adapter, Facade, Mediator) and
  DDD hexagon (bounded contexts, ACL)
- **Complexity findings** → query refactoring smells (Long Method, God Class,
  Feature Envy) for naming, then techniques for resolution
- **State & Data Flow findings** → query DDD hexagon for aggregate boundaries
  and consistency patterns; query design patterns for Observer, Mediator
- **Duplication findings** → query refactoring techniques (Extract Method,
  Extract Class, Pull Up Method)
- **Error Handling findings** → query refactoring techniques (Replace Error
  Code with Exception, Replace Exception with Test) and design patterns
  (Strategy for error recovery, Chain of Responsibility for error propagation)
- **Structure findings** → query DDD hexagon for layer enforcement patterns
- **Extensibility / Variation findings** → query design patterns (Strategy,
  Template Method, Plugin, Registry, Factory)
- **Vertical Slicing findings** → query DDD hexagon for bounded contexts;
  cite Strangler Fig and Branch by Abstraction for incremental slicing
- **Contract Surface findings** → query Adapter, Facade, ACL; cite
  Parallel Change (Expand-Contract) for breaking-change rollouts

### Not in context7 (reference from web/books)

These strategic patterns aren't available as context7 libraries — cite them
by name and link when relevant:

- **Strangler Fig** — [martinfowler.com/bliki/StranglerFigApplication.html](https://martinfowler.com/bliki/StranglerFigApplication.html)
- **Branch by Abstraction** — [martinfowler.com/bliki/BranchByAbstraction.html](https://martinfowler.com/bliki/BranchByAbstraction.html)
- **Mikado Method** — [mikadomethod.info](https://mikadomethod.info/)
- **Parallel Change (Expand-Contract)** — [martinfowler.com/bliki/ParallelChange.html](https://martinfowler.com/bliki/ParallelChange.html)
- **Modular Monolith** — [shopify.engineering/deconstructing-monolith-designing-software-maximizes-developer-productivity](https://shopify.engineering/deconstructing-monolith-designing-software-maximizes-developer-productivity)
- **Vertical Slice Architecture** — Jimmy Bogard
- **Connascence** — [connascence.io](https://connascence.io/); Page-Jones, *What Every Programmer Should Know About OO Design* (1995)
- **The Pragmatic Programmer** — Hunt & Thomas, 20th anniversary ed. (2019)
- **Seam-based refactoring** — *Working Effectively with Legacy Code* (Feathers, 2004)
- **Evolutionary Architecture** — *Building Evolutionary Architectures* (Ford, Parsons, Kua, 2nd ed. 2023)
