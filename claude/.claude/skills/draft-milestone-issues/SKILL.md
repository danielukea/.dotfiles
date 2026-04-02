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
- If the user mentions a project tracker (Linear, Jira, GitHub Issues), ask if you should check it for existing issues

## Phase 2: Interview

Before drafting, ask the user about their preferences. These shape everything:

1. **Slicing style** — "Do you want vertical slices (feature top-to-bottom) or is it okay to have foundation issues that multiple features build on?"
2. **Session size** — "How big should each issue be? For example:
   - **Claude Code session** — completable in a single session (~1-3 files changed, one testable outcome)
   - **Half-day task** — a focused morning or afternoon of work
   - **Multi-day story** — larger chunks for sprint planning"
3. **Who's working** — "How many engineers? Can issues be parallelized across workstreams?"
4. **What to defer** — "Anything from the milestone you want to explicitly defer or descope?"

Adapt based on answers. Don't ask questions the project docs already answer.

## Phase 3: Draft Issues

Create numbered markdown files under `draft_issues/{milestone_name}/`:

```
draft_issues/
  milestone_1/
    01-first-issue.md
    02-second-issue.md
    ...
    README.md
```

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

## Spike Reference
Branch `branch-name`:
- `path/to/relevant/file` — what it does
- `path/to/component` — what it does

## Reference
- Spec §X "Section" → relevant detail
- Discovery Journey Y → which journey this implements
- Roadmap §Z → which milestone bullet this covers
```

Omit sections that don't apply. If there's no spike, drop "Spike Reference". If there are no design decisions, drop that section. The template is a maximum, not a minimum.

### Slicing Principles

- **Outcomes over implementation** — describe what should be true, not how to build it
- **Vertical over horizontal** — each issue delivers a complete capability, not a layer
- **Foundation issues are thin** — just enough shared scaffolding for feature slices to build on
- **Design decisions belong to the assignee** — the issue provides context and options, not mandates
- **Edge cases are acceptance criteria** — not a separate checklist someone ignores
- **Reference the spike, don't copy it** — the spike is inspiration, production adapts it
- **Right-size for the target** — if the user said "Claude Code sessions", each issue should be achievable in a single focused session. If "multi-day stories", issues can be broader.

### README

Write a `README.md` with:
- Milestone goal and audience
- Issue table (number, title, outcome)
- Dependency graph showing what blocks what (use mermaid or ASCII — whichever the user prefers)
- Workstream breakdown (what can be parallelized)

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
