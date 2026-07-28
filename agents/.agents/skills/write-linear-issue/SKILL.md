---
name: write-linear-issue
description: Write an atomic, actionable Linear issue. Use when the user says "write a Linear issue", "create a ticket", or "file this as an issue".
---

# Write a Linear Issue

An issue is a contract with whoever picks it up next — often not you, and increasingly an
agent. It should be **atomic** (one change that can merge on its own), say what changes and
how you'll know it's done, and _point at_ the code rather than reproduce it.

Only the title is load-bearing — per Linear, descriptions are optional. Open one template, not
both: `templates/feature.md` (also chores and tech debt) or `templates/bug.md`.

## Gotchas

- **Acceptance criteria that restate the What aren't criteria.** "Adds a Retry button" is the What again — nobody can fail it. Write what an observer checks from outside: "clicking Retry on a failed sync re-enqueues it and the row leaves the Failed filter."
- **A bug with no repro is a report, not an issue.** Don't invent tidy steps you haven't run —
  a confident repro that doesn't reproduce costs the fixer more than an honest "intermittent,
  seen 3× in prod, request IDs below." Say what you observed and what you already ruled out.
- **Keep an unconfirmed diagnosis out of the title.** "Cache never invalidates" when all you
  know is that the page looks stale hands the fixer your guess and narrows their search before
  they start. Title the symptom; put the suspicion in the body, labeled as a hypothesis.
- **Never write "As a user, I want…".** Linear calls user stories an outright anti-pattern — "a cargo cult ritual that feels good but wastes a lot of resources and time," and "a roundabout way to describe tasks, obscuring the work to be done." State the task and its outcome. A model that has read a lot of Jira drifts back to story phrasing unprompted.
- **Don't transcribe the implementation.** A plan pasted into an issue goes stale the moment the code moves, and it quietly removes the implementer's judgment. Name the entry point and stop — the code is the source of truth, the issue is the contract.
