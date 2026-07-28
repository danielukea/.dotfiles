---
name: write-linear-issue
description: Write an atomic, actionable Linear issue. Use when the user says "write a Linear issue", "create a ticket", or "file this as an issue".
---

# Write a Linear Issue

An issue is a contract with whoever picks it up next — often not you, and increasingly an
agent. It should be **atomic** (one change that can merge on its own), say what changes and
how you'll know it's done, and _point at_ the code rather than reproduce it.

## The shape

Only the title is load-bearing — per Linear, descriptions are optional, not required. Add a
section when it carries something the title can't, and drop it otherwise.

- **Title** — short and scannable; state directly what the task is. Most people read it in a
  list or board, never opening the issue.
- **What** — one or two sentences on the observable change, with a clear defined outcome.
- **Why** _(optional)_ — one line, and only when the What doesn't already imply it.
- **Context / where to begin** _(optional)_ — real paths, symbols, prior issues or PRs.
- **Acceptance criteria** — a short checklist.

## Bugs

A bug is the other register. The gap between expected and actual _is_ the issue, so evidence
replaces the What — and a reliable repro replaces most acceptance criteria, because "the repro
no longer reproduces" is the bar.

- **Title** — the symptom. Not a diagnosis, unless you've confirmed the cause.
- **Summary** — one or two sentences: what breaks, for whom, how badly.
- **Repro** — numbered steps from a known starting state.
- **Expected vs actual** — both, explicitly. Either one alone is unactionable.
- **Evidence** _(optional)_ — error text, stack trace, log line, screenshot, request ID.
- **Environment** _(optional)_ — where it was seen (prod / staging / local), build or commit.
- **Provenance** _(optional)_ — where it surfaced: a PR review, QA of another issue, a support
  thread. Cheap to write, and it's what makes the issue legible months later.

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
