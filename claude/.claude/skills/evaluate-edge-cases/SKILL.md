---
name: evaluate-edge-cases
description: Evaluate draft issues for production edge cases that QA would catch — concurrency, auth lifecycle, validation gaps, error handling, race conditions, data integrity. Dispatches parallel agents by domain. Use when user says "find edge cases", "production risks", "what would QA catch", "evaluate for edge cases", "harden these issues", "what could go wrong", or after auditing issues to strengthen acceptance criteria before implementation.
user-invokeable: true
allowed-tools: Read, Glob, Grep, Write, Edit, AskUserQuestion, Agent
---

# Evaluate Edge Cases

Find production edge cases across a set of draft issues by dispatching domain-specific agents that think like QA engineers trying to break things.

## When to Use

- After drafting and auditing issues, before pushing to a tracker
- User asks "what would QA catch?" or "what could go wrong?"
- User wants to harden issues with acceptance criteria for real-world scenarios

## Phase 1: Gather Inputs

1. **Draft issues directory** — path to `draft_issues/{milestone}/`
2. **Spec path** — for contracts, security requirements, data model details
3. **Discovery doc path** (optional) — for anti-affordances and boundaries

If these were established earlier in the session (e.g., by `/draft-milestone-issues` or `/audit-issues`), reuse them automatically. Otherwise ask.

## Phase 2: Classify Issues by Domain

Read all draft issues and group them by the type of work they involve. Common domains include:

- **UI / User-facing** — forms, dashboards, admin pages, list/detail views, wizards
- **Data model / Backend** — models, migrations, business logic, state machines, APIs
- **Integration / Runtime** — webhooks, external APIs, background jobs, event processing
- **Infrastructure / DevOps** — deployments, configuration, feature flags, monitoring

A single issue may span multiple domains. Assign it to whichever domain covers its riskiest edge cases.

## Phase 3: Dispatch Domain Agents

Dispatch 2-4 parallel agents based on which domains are present. Each agent reads its assigned issues plus relevant spec sections.

Only dispatch agents for domains that have issues. A simple CRUD milestone might only need the UI and Data Model agents. A milestone with external integrations would add the Integration agent.

### Agent Template

Each agent gets the same thinking framework, applied to its domain:

```
You are a QA engineer reviewing draft issues for production edge cases in the {domain} domain.

Read the assigned issues and the spec sections provided.

For each issue, think about these categories and find specific, concrete scenarios:

1. CONCURRENCY — Two users or processes acting on the same resource simultaneously. Race conditions between related operations. Optimistic locking failures.

2. STATE TRANSITIONS — What happens when state changes mid-operation? Resources deleted/deactivated while being viewed or edited. Stale browser tabs. Operations that span multiple states.

3. VALIDATION — Input boundaries (empty, too long, special characters, unicode, injection). Format constraints. Required vs optional fields. Values that are technically valid but semantically wrong.

4. AUTH & SESSION — Session expiration mid-operation. Permission changes mid-session. Multi-tenant boundary enforcement. Credential rotation during active use.

5. DATA INTEGRITY — Cascade behavior on delete/deactivate. Orphaned records. Duplicate creation. Referential integrity across related records.

6. ERROR HANDLING — External service failures (timeouts, malformed responses, DNS failures). Partial failures in multi-step operations. Retry safety (idempotency).

7. SECURITY — Sensitive data in logs or error messages. Cross-tenant data leakage. Credential exposure. Injection vectors.

For each edge case found, report:
- Which issue it affects (by filename)
- The specific scenario (be concrete — "User A edits record while User B deletes it", not "concurrency issues")
- Whether the issue currently addresses it (check the Acceptance Criteria and Edge Cases sections)
- Severity: blocking / high / medium / low
  - blocking: data loss, security breach, or system failure
  - high: incorrect behavior that users will hit in normal usage
  - medium: incorrect behavior in uncommon but realistic scenarios
  - low: cosmetic or minor UX issues under unusual conditions

Focus on scenarios that are realistic in production. Don't invent far-fetched situations — think about what actual users and actual systems will do.
```

### Domain-Specific Additions

On top of the base template, add domain-specific concerns:

**UI / User-facing agents** should also consider:
- Empty states, loading states, error states
- Pagination and large data sets
- Browser back/forward behavior
- Accessibility (keyboard navigation, screen readers)

**Data model / Backend agents** should also consider:
- Migration safety (zero-downtime deploys, rollback)
- Query performance with realistic data volumes
- Enum/state machine transitions that skip steps

**Integration / Runtime agents** should also consider:
- Webhook/callback payload validation
- Rate limiting and backpressure
- Circuit breaker behavior
- Timeout cascades

**Infrastructure agents** should also consider:
- Configuration drift between environments
- Feature flag lifecycle (cleanup, stale flags)
- Monitoring and alerting gaps

## Phase 4: Consolidate Report

After all agents report, consolidate into a grouped report:

```markdown
## Edge Case Report: {Milestone}

### Summary
- X blocking, Y high, Z medium edge cases found
- N already addressed in issues, M need attention

### By Category

#### Concurrency (X findings)
| Issue | Scenario | Addressed? | Severity |
|-------|----------|-----------|----------|
| ... | ... | ... | ... |

#### Auth & Session Lifecycle (X findings)
...

#### Validation (X findings)
...

#### Data Integrity (X findings)
...

#### Security (X findings)
...

### Recommendations
For each unaddressed edge case, recommend one of:
- **Add to acceptance criteria** — natural part of building the feature
- **Add to edge cases section** — something the assignee should handle but isn't an AC
- **New issue** — cross-cutting concern that deserves its own work item
- **Defer** — real risk but out of scope for this milestone
```

## Phase 5: Triage with User

Present the report and ask: "How do you want to handle these? I can update the issues based on your decisions."

Walk through the findings by severity (blocking first). For each, the user decides: add to issue, new issue, defer, or dismiss.

Then for each accepted recommendation:
- **Acceptance criteria / edge case**: Edit the issue's markdown file
- **New issue**: Draft a new markdown file in the same directory, update the README
- **Defer**: Note in the README under a "Deferred Edge Cases" section

## Next Step

After edge cases are triaged and applied, suggest:

> Edge cases applied. Next step:
> 1. `/push-issues-to-linear` — create these issues in your project tracker
