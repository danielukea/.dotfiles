---
name: draft-milestone-issues
description: Draft issues for a project milestone by reading project context (spec, roadmap, discovery, spike), interviewing about slicing preferences, and writing numbered markdown files with acceptance criteria. Use when user says "draft issues", "create issues for milestone", "break down this milestone", "plan issues for M1", "break this into tickets", "plan the sprint", "what issues do we need", or wants to turn a roadmap milestone into actionable issues. Also use when the user has a roadmap and wants to start planning implementation work.
user-invokeable: true
allowed-tools: Read, Write, Edit, Glob, Grep, AskUserQuestion, Agent
---

# Draft Milestone Issues

Turn a roadmap milestone into a set of well-scoped issues, drafted as local markdown files for review before pushing to a tracker.

## Phase 1: Gather Context

Read project documentation to build understanding. Search the project directory and `~/Workspace/notes/projects/` for:

1. **Spec** — the truth document (architecture, data model, contracts)
2. **Roadmap** — milestone definitions with slices
3. **Discovery doc** — user stories, journeys, affordance maps
4. **Spike/PR summary** — what's been prototyped, key files touched
5. **Project index** — links, team, decisions

If paths aren't obvious, ask: "Where are your project docs? I'm looking for a roadmap, spec, or discovery doc."

Also check for existing issues to avoid duplication:
- Search `draft_issues/` for previously drafted issues
- If the project uses Linear (or another tracker), check for existing issues in the same project that might overlap with this milestone. Use `list_issues` filtered by project. Issues from earlier milestones may already cover items in this milestone's roadmap definition.

## Phase 1.5: Deep Spike Audit

If a spike branch or prototype exists, dispatch an Explore agent to thoroughly map the implementation before drafting issues. Shallow spike references ("no diff view in spike") waste time and require expensive rework later.

The agent should map every significant file: models, controllers, service objects, concerns, jobs, migrations, React components, admin resources, and routes. For each file, note what it does and which milestone area it relates to.

The output becomes the "Spike Reference" sections in each issue. Every issue should clearly state: **what the spike already covers** and **what's still missing**. This distinction is the most valuable part of the spike reference — it tells the assignee whether they're building on existing code or starting from scratch.

## Phase 1.6: Master Branch Infrastructure Check

**This is the highest-ROI phase. Treat it as non-skippable — every "build X" ticket drafted for something already on master is wasted scope you'll have to re-litigate when someone catches it later.** A real failure mode looks like: a ticket titled `[NEW] Build state machine for versions` shipped after the model already declares the state machine on master. Phase 1.6 catches this.

Before drafting, check the main branch for existing code that this milestone's issues might reuse or already cover. Search broadly for patterns, utilities, models, concerns, validators, and infrastructure related to the milestone's domains. Examples:
- Sanitization/security utilities the milestone needs (e.g. `PromptSafety`, `SecureUrlValidator`)
- Retry/backoff utilities the milestone needs (e.g. `Utilities::ExponentialBackoff`)
- Models the milestone might assume don't exist (e.g. `PartnerMembership`, `WebhookDelivery`)
- State machines / transitions already declared on existing models
- Existing audit logging patterns to follow
- Similar features that establish conventions

For substantive milestones, dispatch parallel Explore agents — one per major surface (e.g. composer, AA, dev portal, models). Each agent reports what's done / partial / missing for the milestone's deliverables.

Two outcomes per finding:
1. **Already shipped** — the issue should be **omitted** from the draft, or written as a **delta** ("AC: extend `X` with column Y") rather than "build X from scratch"
2. **Partial** — the issue's scope **shrinks** to the missing pieces; note "Existing Infrastructure on Master" listing what to reuse

Skipping this phase is the most common cause of drafted milestones that read as "build the foundation" when the foundation already exists. The cost of running it is one extra phase; the cost of skipping it is restructuring the milestone after someone audits the codebase.

## Phase 1.7: Decisions Log

Check the project directory and `~/Workspace/notes/projects/{project}/` for `decisions.md`. If it exists, read it before the Phase 2 interview.

The decisions log captures durable choices made in prior drafting sessions for this project — slicing style, what's deferred, walking-skeleton splits, scope cuts. Use it to **skip questions already answered**:

- Don't re-ask "vertical or horizontal slicing" if the log records the answer
- Don't re-propose deferring something the log already deferred
- Don't re-litigate parent-epic structure unless evidence has changed

When the log conflicts with what the current docs/code show (e.g. log says "memberships deferred to M3" but code shows the model exists on master), surface the conflict to the user — don't silently override either.

If `decisions.md` doesn't exist, that's fine. Phase 5 creates one after this drafting run.

## Phase 2: Interview

Before drafting, ask the user about their preferences. These shape everything:

1. **Slicing style** — "Do you want vertical slices (feature top-to-bottom) or is it okay to have foundation issues that multiple features build on?"
2. **Session size** — "How big should each issue be? For example:
   - **Claude Code session** — completable in a single session (~1-3 files changed, one testable outcome)
   - **Half-day task** — a focused morning or afternoon of work
   - **Multi-day story** — larger chunks for sprint planning"
3. **Who's working** — "How many engineers? Can issues be parallelized across workstreams?"
4. **What to defer** — "Anything from the milestone you want to explicitly defer or descope?" When recommending deferrals yourself, consider the domain and end users — don't defer features that are core to how users actually work just because they're technically complex.
5. **Progressive enhancement** — For each major feature area, propose the smallest useful version and what layers on later. Confirm with the user before drafting. Example: "OAuth test flow could be just a token exchange button (M3), with per-URI testing and scope verification in M3.5. Does that split feel right?"
6. **Walking skeleton** — "What's the thinnest end-to-end demo this milestone could ship? The skeleton: minimum depth across all layers, demoable as one slice. Polish: the issues that thicken the skeleton once it integrates." Identify which issues are skeleton and which are polish. Polish issues become explicit second-wave dependencies (their bodies say "depends on skeleton issue X for Y") — they don't get drafted as if from scratch when the skeleton already provides foundations.

   This question is the highest-leverage one in the interview. Drafting without it produces a horizontally-sequenced milestone where nothing integrates until the last issue lands; drafting with it produces a milestone where one full slice is demoable early and polish layers on in parallel. If the user resists picking a skeleton ("we need all of it"), gently push: *which issue is the one that, if it shipped alone, would still demonstrate the milestone's value most clearly?* That's your skeleton anchor.

**Before asking, check project docs and `decisions.md` (Phase 1.7) for answers.** CLAUDE.md, the project index, the roadmap, and the decisions log often contain team size, who's working, what's explicitly deferred, and prior slicing decisions. Only ask questions the docs and log don't answer. Adapt based on answers.

## Phase 3: Draft Issues

Create numbered markdown files under `draft_issues/{milestone_name}/`, organized by parent issue directories:

```
draft_issues/
  milestone_1/
    parent-issue-name/
      01-first-child.md
      02-second-child.md
    another-parent/
      01-first-child.md
    README.md
```

Each directory is a **parent issue** — an increment of value delivered to a user type. The directory name answers: "what can a partner/firm/user *do* after this ships that they couldn't before?" Parent issues are not demo themes or horizontal categories — they represent value rolled out incrementally.

Issues within a directory are numbered sequentially starting from 01. The README references all issues with relative paths.

### Issue Template

Every issue follows this structure:

```markdown
# Title

## Outcome
One sentence describing what's true when this issue is done.

## Acceptance Criteria
- [ ] First observable outcome
- [ ] Second observable outcome
- [ ] Each item is testable and from the user/business perspective

## Edge Cases
- Concurrency, validation, error states the assignee should handle
- Only include edge cases relevant to THIS issue

## Design Decisions for Assignee
- **Decision name:** Context from spike/spec. The assignee decides, not this issue.
- Decisions are things where the spec or spike offers options, not mandates

## Existing Infrastructure on Master
- `path/to/existing/utility.rb` — what it does, how this issue can reuse it
(Only include if Phase 1.6 found relevant code)

## Spike Reference
Branch `branch-name`:
- `path/to/relevant/file` — what it does
- `path/to/component` — what it does

**What the spike already covers:** ...
**What's missing:** ...

## Reference
- Spec §X "Section" → relevant detail
- Discovery Journey Y → which journey this implements
- Roadmap §Z → which milestone bullet this covers
```

Omit sections that don't apply. If there's no spike, drop "Spike Reference". If there are no design decisions, drop that section. The template is a maximum, not a minimum.

### Body Discipline

These rules govern what goes inside an issue body. Each one is here because skipping it costs real cleanup work later.

- **ACs are outcomes, never schema or implementation choices.** "Notes can be tagged with scope (general / tool / webhook)" is an outcome — observable, testable. "Add `scope` enum column to `ReviewNote` model" is implementation — that's the assignee's choice given the actual constraints. Schema columns, polymorphism vs. direct FK, concern names, gem choices, table names: never in ACs. The rule is enforced in service of *implementer freedom* — if the AC prescribes the design, the assignee can't push back when their context reveals a better path.

- **Notes section is for inspiration patterns, not mandates.** When you reference a similar pattern elsewhere in the codebase (e.g. "see `~/Workspace/fizzy/app/models/concerns/eventable.rb` for an aggregate-events pattern"), frame it as *inspiration* — something the assignee can borrow from if it fits, not something they must use. The same rule applies to the spike: spike code is exploratory and the assignee redesigns from the ticket's outcomes, never copies.

- **For UPDATE/sharpen entries, write the complete replacement body.** If a milestone has existing issues whose scope changed (because the codebase moved, or scope shifted to a sibling milestone, or the parent restructured), produce the *full new body* — Goal, Why, AC, Out of scope, Notes — that the executor pastes verbatim. Do not produce "drop AC #3, add new AC about Y" preambles. The executor copies, doesn't reason. A scope-note line above the new body is fine ("Scope note YYYY-MM-DD: shrunk because M1's X now ships the foundation"), but the body below it must be self-consistent — no orphaned ACs from the prior version.

- **Self-contained.** Every issue body should make sense to someone reading it cold. No "see prior session," no "consolidates AIE-1234 + 5678," no "replaces the AA shim." Cross-references to other tickets are fine when they're scope clarifications ("Diff view is a separate ticket — not in scope here"). Session metadata is not.

### Slicing Principles

- **Progressive enhancement** — for every feature area, ship the smallest useful version first. List what layers on later in the deferred section, not as acceptance criteria. Ask "what's the minimal slice that delivers value?" before drafting.
- **Vertical features, thin foundations** — feature issues should be vertical slices (top-to-bottom through the stack). Only split backend/frontend when the issue is shared infrastructure that multiple features depend on. Once foundations land, keep features vertical. Split when:
  - Issue has shared infrastructure (models, strategies, concerns) that multiple features build on → extract as a thin foundation issue
  - Issue has a security/validation concern that applies broadly → extract as shared concern
  - Issue covers two user types doing fundamentally different things → split per user type
- **Outcomes over implementation** — describe what should be true, not how to build it
- **Vertical over horizontal** — each issue delivers a complete capability, not a layer
- **Foundation issues are thin** — just enough shared scaffolding for feature slices to build on
- **Design decisions belong to the assignee** — the issue provides context and options, not mandates
- **Edge cases are acceptance criteria** — not a separate checklist someone ignores
- **Reference the spike, don't copy it** — the spike is inspiration, production adapts it
- **Right-size for the target** — if the user said "Claude Code sessions", each issue should be achievable in a single focused session. If "multi-day stories", issues can be broader.
- **Domain-aware deferral** — when recommending what to defer, consider the end users and their actual workflows, not just technical complexity. A technically complex feature that's core to how users actually work should stay in scope. A technically simple feature that's nice-to-have can defer.

### Vertical Integration Check

Before finalizing, walk each child issue and verify:

1. **Does it have a user-visible demo?** Something you could record a 30-second GIF of. If the only evidence of completion is a green test suite, it's probably a horizontal layer, not a feature.
2. **Does it have independent value?** Can this ship alone, or does it need two siblings to land first to be observable? Independent = ship it. Coupled = consider merging.
3. **Is it a horizontal layer masquerading as a feature?** Red-flag titles: `Foundation: CRUD API`, `Infrastructure:`, `*Model + ...`, `Feature flag setup`, `Scaffolding`. These rarely deserve standalone issues — they nest under (or absorb into) the feature that first needs them. The model "falls out of the form's needs."
4. **Is it a feature flag issue?** If the flag mechanism already exists in the codebase (Flipper, LaunchDarkly, etc.), adding one config line is not an issue — it belongs inside whichever feature first gates on it.
5. **Does the body match the title?** When you've been editing existing issues (sharpens, supersessions, retitles), check that the body actually describes what the title says. A common failure: ticket retitled to "X polish" with a scope note saying "M1 ships the base," but the body still contains the base-building ACs from before the retitle. The body must be self-consistent — see "Body Discipline" above.
6. **Is the skeleton/polish split legible from the body?** For a polish issue (per Phase 2 walking-skeleton question), the body should explicitly reference what the skeleton ships and what's left for this issue. A reader should be able to tell whether they're picking up skeleton work or polish work from the issue alone.

Count children per parent. **If a parent has materially more children than your plan intended (e.g., plan said 8, reality is 14), horizontal creep has snuck in.** Run the four checks above on each one.

Model-foundation issues are a common offender: they get split out for DB-layer work, then sit alongside the feature that uses them. If they have active work (branches, PRs), don't delete — nest them under the feature issue as sub-children. The three-level hierarchy (slice parent → feature → model) reads cleanly and preserves history.

### Parent Issues (Value Increments)

Group issues into **parent issues** — increments of value delivered to a user type. Each parent becomes a parent issue when pushed to Linear, with its children as the individual work items. Each parent is also a directory under `draft_issues/{milestone_name}/`.

The test for a good parent: **"What can a user *do* after this ships that they couldn't before?"** Each parent answers this with one sentence describing the new capability.

Guidelines:
- **2-5 issues per parent** is the sweet spot. Small enough to ship incrementally.
- **Parents represent value, not architecture.** "Partner manages their own OAuth apps" (good) vs. "OAuth infrastructure" (bad — that's a horizontal layer, not a value increment).
- **Keep parents as small as possible.** If a parent has 6+ issues, look for a natural split into two value increments.
- **Cross-cutting work** (security, rate limiting, metrics) that doesn't directly unlock new user capability can group under an operational parent like "Safe at Scale" — framed as "we can confidently onboard N partners without things breaking."
- **4-6 parents per milestone is typical.** Too few = too big. Too many = tracking tasks, not value.

### README

Write a `README.md` with:
- Milestone goal and audience
- **Parent issue table** (parent name, value delivered, issue count)
- Issue tables grouped by parent (number, title, outcome) with relative paths to issue files
- Dependency graph showing what blocks what (use mermaid with subgraphs per parent — minimize edges, only true blockers)
- Workstream breakdown (what can be parallelized)
- Deferred items list (what layers on in the next milestone)

## Phase 4: Review with User

After drafting, present the issue list and dependency graph. Ask:
- "Does the granularity feel right?"
- "Any issues that should be split or merged?"
- "Missing anything from the milestone?"

Iterate based on feedback. This is collaborative — expect 2-3 rounds of restructuring.

## Phase 5: Update Decisions Log

After the user is happy with the draft, append today's durable decisions to `decisions.md` in the project directory (create the file if it doesn't exist). The log is what Phase 1.7 reads in future drafting sessions to avoid relitigation.

Capture only **durable** decisions — choices that should persist beyond this drafting run and that future sessions would otherwise re-ask:
- Slicing style (vertical vs. horizontal-foundation)
- What's been explicitly deferred and why
- Walking-skeleton split — which issues are skeleton, which are polish
- Major scope cuts ("V20 distributed into V11/V12 ACs instead of standalone scope")
- Architectural calls ("review notes use direct FK to Version, not polymorphic")
- Cross-milestone supersessions ("AIE-1721 superseded by M1 review skeleton")

Skip transient choices — exact wording of an AC, which Figma frame to reference, etc.

Format each entry:

```markdown
## YYYY-MM-DD — Topic
**Decision**: One-line answer.
**Why**: One-line rationale, ideally with the constraint or evidence that drove it.
**Alternatives considered**: brief list (one phrase each).
```

Append to the bottom; don't reorder. The log is chronological.

## Path Inference

If a previous skill in this session already established paths (e.g., roadmap skill created `roadmap.md`, or `draft_issues/` already exists), use them automatically instead of asking again. Only ask when paths are ambiguous.

## Next Step

After drafting is complete and the user is happy with the issues, suggest:

> Issues are drafted. Next steps:
> 1. `/audit-issues` — check these against the roadmap and spike for gaps
> 2. `/evaluate-edge-cases` — find production edge cases to add as acceptance criteria
> 3. `/push-issues-to-linear` — create these in your project tracker when ready
