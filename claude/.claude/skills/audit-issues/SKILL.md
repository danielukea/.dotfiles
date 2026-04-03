---
name: audit-issues
description: Audit draft issues against the project plan, spec, and spike to find gaps, overscopes, and missing coverage. Use when user says "audit these issues", "are we missing anything", "check against the plan", "review the issues", "sanity check these issues", "verify completeness", "did I miss anything", or after drafting milestone issues to verify they fully cover the roadmap before pushing to a tracker.
user-invokeable: true
allowed-tools: Read, Glob, Grep, Write, Edit, AskUserQuestion, Agent
---

# Audit Issues

Compare a set of draft issues against the project's roadmap, spec, and spike implementation to find what's missing, what's over-scoped, and what's covered.

## When to Use

- After drafting milestone issues (natural next step from `/draft-milestone-issues`)
- User asks "are we missing anything?" or "did I cover everything?"
- User wants to verify issues match the plan before pushing to a tracker

## Phase 1: Gather Inputs

The skill needs:
1. **Draft issues directory** — path to the `draft_issues/{milestone}/` folder
2. **Project docs** — spec, roadmap, discovery doc

If these were established earlier in the session (e.g., by `/draft-milestone-issues`), reuse those paths automatically. Otherwise, search the project directory and `~/Workspace/notes/projects/` for likely candidates, and confirm with the user.

Optionally:
3. **Spike branch** — branch name and worktree path, if a prototype exists. Ask: "Is there a spike branch I should compare against? If not, I'll skip implementation gap analysis."

## Phase 2: Audit

Dispatch 2-4 parallel subagents, each focused on a different audit dimension. Only dispatch agents that are relevant — if there's no spike, skip the spike agent.

### Agent 1: Roadmap Coverage

```
Read all draft issues in {issues_directory}.
Read the roadmap milestone definition in {roadmap_path} (section for this milestone).
Read the spec sections relevant to this milestone.

For each bullet in the roadmap milestone definition:
- Is there an issue that covers it? → ✅ Covered by issue #{filename}
- Is it missing? → ❌ Not covered — {what's missing}

For each draft issue:
- Does it go beyond the milestone scope? → ⚠️ Over-scope — {what's extra}

For items flagged as gaps, check if they're covered by issues in other milestones
(earlier or later). A gap in M2 isn't a gap if M1 already handles it. Check
draft_issues/ for other milestone directories and read their READMEs.

Report as a checklist.
```

### Agent 2: Spike Gap Analysis (only if a spike exists)

```
Explore the spike branch at {worktree_path} on branch {branch_name}.

Map every significant file the spike added:
- Models, controllers, components, migrations, tests, configuration, jobs

For each spike component, check if it's covered by a draft issue.
Report:
- ✅ Covered by issue #{filename}
- ❌ Not in any issue — {what it is, whether the milestone needs it}
- ⚠️ Partially covered — {what's missing}
```

### Agent 3: Cross-Cutting Concerns (when the milestone involves infrastructure, auth, or shared systems)

```
Check for:
- Infrastructure or test setup mentioned in docs but not in issues
- Cross-cutting concerns (auth, feature flags, locking, logging) that multiple issues depend on but no single issue owns
- Dependencies between issues that aren't reflected in the README dependency graph
- Shared scaffolding that needs to exist before feature issues can start

For each resource the issues create (models, admin pages, portal features),
verify the full CRUD lifecycle is covered. If issues create a resource but don't
provide ways to update, delete, or manage its lifecycle, flag the gap. Think about:
- Can the resource be edited after creation?
- Can it be deleted/archived/deactivated?
- Are there domain-specific lifecycle operations missing (submit/withdraw, approve/revoke, etc.)?
```

Run Agent 3 when the milestone involves new infrastructure, auth changes, cross-cutting concerns, or when the spec mentions shared systems. Skip it for milestones that are purely feature work on existing foundations.

### Agent 4: Master Branch Overlap (recommended for most milestones)

```
Search the main branch of the codebase for existing code that overlaps with
or could be reused by the drafted issues. Focus on:

- Utilities, concerns, and service objects that issues might reinvent
- Existing patterns (audit logging, retry, sanitization, circuit breaking) that issues should follow
- Infrastructure that issues assume doesn't exist but actually does
- Recent merges that may have brought relevant code from other branches

For each finding, report:
- What exists on master (file path, what it does)
- Which draft issue(s) it affects
- Whether the issue should be eliminated, reduced in scope, or updated to reference it

Run git log for the last 3 months to find recent relevant merges.
```

This agent has high ROI — it frequently finds existing utilities that eliminate entire issues or reduce them to a few lines of wiring. Skip only if the milestone is greenfield with no relevant existing code.

## Phase 3: Report

Consolidate agent results into a single report:

```markdown
## Audit Report: {Milestone Name}

### Roadmap Coverage
✅ N/M bullets covered
❌ X gaps found:
- {gap 1}
- {gap 2}

### Spike Coverage (if applicable)
✅ N/M components covered
❌ X not in any issue:
- {component} — {whether the milestone needs it}

### Master Branch Overlap (if applicable)
- {utility/pattern} on master → affects issue #{filename} — {eliminate, reduce, or reference}

### Over-Scope
⚠️ N issues extend beyond the milestone:
- {issue} — {what's extra}

### Missing Dependencies / CRUD Gaps
- {any cross-cutting concerns not captured}
- {any resources without full lifecycle coverage}

### Recommendations
- {specific actions: new issues to create, issues to update, scope to trim}
```

Present the report and ask the user how they want to handle each gap. Don't make changes unilaterally — let the user decide what to add, trim, or defer.

## Phase 4: Apply Changes

For each gap the user wants to address:
- **New issue needed** — draft a new markdown file in the same `draft_issues/` directory
- **Issue needs updating** — edit the existing markdown file
- **Over-scope to trim** — remove or relocate content, noting where it should go instead
- **Defer to later milestone** — note the deferral in the README

Update the README dependency graph and issue table after changes.

## Next Step

After the audit is resolved (gaps filled, overscopes trimmed), suggest:

> Audit complete. Next steps:
> 1. `/evaluate-edge-cases` — find production edge cases (concurrency, auth, validation) to harden the issues
> 2. `/push-issues-to-linear` — create these in your project tracker when ready
