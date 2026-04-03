---
name: arch-analysis
description: >
  Deep architectural analysis of any codebase using parallel exploration agents.
  Each agent examines a different dimension (coupling, complexity, churn, state
  management, duplication, error handling) and produces structured findings that
  get synthesized into a prioritized improvement report. Use this skill whenever
  the user says "analyze architecture", "find architectural improvements",
  "codebase analysis", "what should we refactor", "tech debt audit", "code health
  check", "architectural review", or asks about structural problems, hotspots,
  coupling issues, or code quality across the whole codebase. Also use when the
  user wants to understand the overall shape of an unfamiliar codebase before
  making changes. This is different from code-review (which examines a diff) —
  this examines the entire codebase as it exists today.
user-invokeable: true
allowed-tools: Read, Glob, Grep, Bash, Write, Edit, Agent, AskUserQuestion
---

# Architectural Analysis

Dispatch 6 parallel agents to examine a codebase from orthogonal angles, then
synthesize findings into a prioritized report with concrete evidence.

**Not this skill:** Reviewing a PR → `code-review`. Exploring one feature →
`explore`. Planning a known feature → `writing-plans`.

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
Polyglot repos get multiple stack tags.

### Check available CLI tools

```bash
for tool in scc ast-grep dep-tree jscpd semgrep knip madge depcruise radon rubocop brakeman vulture mergestat; do
  command -v "$tool" &>/dev/null && echo "available: $tool" || echo "missing: $tool"
done
```

Agents adapt to what's installed. Everything works with just grep/glob/read —
CLI tools add richer quantitative data.

If the user wants to install tools first, see `references/tools.md` for the
recommended install list organized by lens and language.

### Estimate codebase size

```bash
# Quick size check to calibrate agent dispatch
find . -type f \( -name '*.rb' -o -name '*.py' -o -name '*.ts' -o -name '*.tsx' -o -name '*.js' -o -name '*.jsx' -o -name '*.rs' -o -name '*.go' -o -name '*.java' -o -name '*.kt' -o -name '*.ex' -o -name '*.exs' -o -name '*.cs' \) | wc -l
git rev-list --count HEAD 2>/dev/null || echo "0"
```

**Adaptive dispatch rules:**
- < 20 source files → skip Duplication agent (not enough surface area)
- < 50 git commits → skip churn portion of Complexity & Churn agent
- Monorepo with distinct packages → tell agents to analyze per-package

---

## Phase 1: Parallel Exploration (6 Agents)

Read each agent's prompt from `references/<lens>.md` before dispatching.
Dispatch all 6 simultaneously via the Agent tool. Each agent receives:

- Detected tech stack(s)
- Available CLI tools list
- Project root path
- Its lens-specific prompt from references/

| # | Lens | Prompt | What it finds |
|---|------|--------|---------------|
| 1 | **Coupling** | `references/coupling.md` | Circular deps, layer violations, import graphs, module boundaries |
| 2 | **Complexity & Churn** | `references/complexity-churn.md` | Hotspots where high complexity meets frequent changes |
| 3 | **State & Data Flow** | `references/state.md` | Persistence patterns, data consistency, race conditions |
| 4 | **Duplication & Patterns** | `references/duplication.md` | Copy-paste code, emerging abstractions worth extracting |
| 5 | **Error Handling & Resilience** | `references/errors.md` | Silent failures, inconsistent error propagation, resource leaks |
| 6 | **Structure & Conventions** | `references/structure.md` | File organization, naming drift, dead code, public API surface |

**Why 6 orthogonal lenses?** A single agent exploring everything hits context
limits and loses focus. These lenses were chosen because they surface different
categories of issues — coupling analysis never finds churn problems, and churn
analysis never catches layer violations. Running them in parallel cuts wall time
from ~6 minutes to ~1 minute.

### Agent output format

Every agent structures its response as:

```
### What's Working Well
- [observation] — [evidence: file paths, patterns]

### Findings
For each finding:
- **Finding**: One-line summary
- **Severity**: high / medium / low
- **Evidence**: File paths, line numbers, metrics, CLI tool output
- **Impact**: What breaks or degrades if unaddressed
- **Suggestion**: Concrete direction (not a full implementation plan)

### Metrics
- [metric]: [value] — [interpretation]
  (only if CLI tools produced quantitative data)
```

---

## Phase 2: Synthesis

After all agents return:

1. **Detect convergence.** When multiple agents independently flag the same area,
   call it out explicitly — convergence from independent lenses is a strong
   signal. A medium finding flagged by 3 agents outranks a high finding from 1.

2. **Deduplicate and categorize** into:
   - Architecture & Coupling
   - Code Health & Complexity
   - Data Integrity & State
   - Reliability & Error Handling
   - Maintainability & Conventions

3. **Produce the report:**

```markdown
# Architectural Analysis: {project}

## Stack & Size
{detected stack, frameworks, file count, commit count}

## What's Working Well
{consolidated positives — important for calibrating the findings}

## Top Findings (ranked by impact)

### 1. {Title}
**Category**: ...  |  **Severity**: high/medium/low
**Flagged by**: {agent 1, agent 3} ← convergence signal
**Evidence**: {file paths, metrics, tool output}
**Impact**: {consequence of inaction}
**Direction**: {concrete next step, not a full plan}

### 2. ...
(top 5–8 findings)

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

The skill surfaces evidence; the human decides what matters given project phase,
team capacity, and upcoming work.

---

## Phase 4: Plan Generation (optional)

If the user picks items and says "plan it":

1. Invoke `writing-plans` for the selected improvements
2. After the plan is written, invoke `code-review` on the plan to catch
   convention violations early

Discovery and execution stay separate.

---

## Limitations

- **Periodic use** — monthly or at milestones, not daily. Six agents are expensive.
- **No auto-refactor** — output is a report (and optionally a plan).
- **Git history helps** — churn analysis needs commits. New repos benefit less.
- **CLI tools are optional** — enrich but don't gate the analysis.
