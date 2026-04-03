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

Before drafting, check the main branch for existing code that this milestone's issues might reuse. This prevents drafting issues for work that already exists (or significantly reduces their scope).

Search for patterns, utilities, concerns, and infrastructure related to the milestone's domains. Examples of what to look for:
- Sanitization/security utilities the milestone needs
- Retry/backoff utilities the milestone needs
- Existing audit logging patterns to follow
- Similar features that establish conventions

Note findings as "Existing Infrastructure on Master" sections in relevant issues. This step has high ROI — in practice it has eliminated entire issues and reduced others to a few lines of wiring.

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

**Before asking, check project docs for answers.** CLAUDE.md, the project index, and the roadmap often contain team size, who's working, and what's explicitly deferred. Only ask questions the docs don't answer. Adapt based on answers.

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

## Path Inference

If a previous skill in this session already established paths (e.g., roadmap skill created `roadmap.md`, or `draft_issues/` already exists), use them automatically instead of asking again. Only ask when paths are ambiguous.

## Next Step

After drafting is complete and the user is happy with the issues, suggest:

> Issues are drafted. Next steps:
> 1. `/audit-issues` — check these against the roadmap and spike for gaps
> 2. `/evaluate-edge-cases` — find production edge cases to add as acceptance criteria
> 3. `/push-issues-to-linear` — create these in your project tracker when ready
