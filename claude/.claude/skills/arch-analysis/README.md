# Recommendation: `arch-analysis` Skill

## What Happened This Session

A single user prompt — "Analyze this codebase for architectural improvements" — triggered a multi-phase workflow:

1. **Parallel exploration** (6 agents, ~60s) — Each agent examined one dimension of the codebase: module coupling, state management, TUI architecture, CLI patterns, git churn history, and error handling/process interaction.

2. **Synthesis** — Agent findings were combined into a ranked list of architectural improvements with concrete evidence (file paths, line numbers, duplication counts, churn data).

3. **Prioritization** — User narrowed from 5 candidates to top 3 through conversation.

4. **Plan generation** — A full implementation plan was written using the `writing-plans` skill, with TDD steps, exact code, and commit boundaries.

5. **Convention review** — A code-reviewer agent checked the plan against CLAUDE.md rules, finding a TDD ordering bug and several defensive programming issues.

This took ~20 minutes of wall time. Most of it was mechanical — the exploration agents ran the same patterns every time (grep for imports, read module files, trace data flow, check git log). The synthesis and prioritization required human judgment, but the data gathering didn't.

## Proposed Skill: `arch-analysis`

### Trigger

When user says "analyze architecture", "find architectural improvements", "codebase analysis", "what should we refactor", "tech debt audit", or similar.

### What It Does

**Phase 1: Automated Exploration (parallel agents)**

Dispatch 6 agents simultaneously, each with a focused lens:

| Agent | Lens | Key Questions |
|-------|------|---------------|
| Coupling | Module dependencies | Who imports whom? Layer violations? Circular deps? |
| Complexity & Churn | Hotspots | High-change files? Bug-fix clusters? Cyclomatic complexity? |
| State & Data Flow | Persistence & consistency | Load/save patterns? Race conditions? Data integrity? |
| Duplication & Patterns | Copy-paste & abstractions | Emerging patterns? Repeated logic? Missing abstractions? |
| Error Handling | Resilience | Silent failures? Inconsistent error propagation? Resource leaks? |
| Structure & Conventions | Organization | File layout? Naming drift? Dead code? Public API surface? |

Each agent gets a structured prompt template that adapts to the project's tech stack (Rust/Rails/React/etc.) detected from `Cargo.toml`, `Gemfile`, `package.json`, etc.

**Phase 2: Synthesis (main agent)**

Combine findings into a structured report:
- What's working well (don't fix what isn't broken)
- Emerging patterns worth extracting
- Risk areas (safety, consistency, race conditions)
- Churn hotspots (where instability lives)
- Ranked improvements with effort/impact assessment

**Phase 3: Interactive Prioritization**

Present the top 5 candidates. Ask the user to pick 2-3. This is the human judgment step — the skill doesn't auto-decide what to refactor.

**Phase 4: Plan Generation (optional)**

If user says "plan it", invoke `writing-plans` for the selected improvements. Then auto-invoke `code-reviewer` to check the plan against project conventions.

### Skill Structure

```
skills/arch-analysis/
  SKILL.md                     # Main skill (phases 0-4 + context7 references)
  README.md                    # Design rationale (this file)
  references/
    coupling.md                # Circular deps, layer violations, import graphs
    complexity-churn.md        # Hotspots where high complexity meets frequent changes
    state.md                   # Persistence patterns, data consistency, race conditions
    duplication.md             # Copy-paste code, emerging abstractions
    errors.md                  # Silent failures, error propagation, resource leaks
    structure.md               # File organization, naming drift, dead code
    tools.md                   # Recommended CLI tools by lens and language
```

### Key Design Decisions

**Why 6 specific lenses instead of one big agent?**

A single agent exploring everything hits context limits and loses focus. The 6 lenses were chosen because they consistently surface different categories of issues — coupling analysis never finds churn problems, and churn analysis never finds layer violations. Parallel execution also cuts wall time from ~6 minutes to ~1 minute.

**Why is prioritization interactive?**

The skill surfaces evidence, but "what should we refactor" depends on project phase, team bandwidth, and upcoming features. A skill that auto-picks priorities would be wrong half the time. The human picks; the skill ensures they pick from a well-researched menu.

**Why detect tech stack?**

The agent prompts need to know what to look for. "Check for `let _ =` on Result types" is Rust-specific. "Look for N+1 queries" is Rails-specific. "Check for useEffect cleanup" is React-specific. The prompts should adapt.

**Why not just use `code-review`?**

Code review examines a diff — what changed. Architecture analysis examines the whole codebase — what exists, what's emerging, what's drifting. Different inputs, different outputs, different agents.

### What This Session Taught Us

1. **The exploration prompts matter more than the synthesis.** Good prompts produced findings that practically wrote themselves into a report. Bad prompts (too vague, too broad) would have produced noise.

2. **Git churn data is surprisingly useful.** Knowing that `tui/ui.rs` had 12 modifications in 50 commits immediately told us where instability lives — more useful than any static analysis.

3. **Convention review on the plan caught real bugs.** The TDD ordering violation would have been caught during execution, but catching it in the plan saved a full iteration cycle.

4. **The user only needed to make one decision** — which 3 improvements to prioritize. Everything else was automation. That's the right ratio for a skill.

### Scope and Limitations

**This skill is for periodic use** — monthly or at project milestones, not daily. Running 6 exploration agents is expensive and the findings don't change hour-to-hour.

**It does not auto-refactor.** The output is a report and optionally a plan. Execution is a separate step with its own skill (`executing-plans` or `subagent-driven-development`).

**It works best on codebases with git history.** The churn analysis agent needs commits to analyze. A brand-new repo with 3 commits won't benefit from that lens.

### Next Steps

1. Extract the 6 agent prompts from this session into reusable templates
2. Add tech stack detection (read Cargo.toml/Gemfile/package.json to select prompt variants)
3. Build the synthesis phase as a structured template (not freeform — force the "what's working / what's not / ranked improvements" structure)
4. Wire up the optional plan generation handoff to `writing-plans`
5. Test on 2-3 different repos to validate the lenses generalize
