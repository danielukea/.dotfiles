---
name: tdd
description: >
  The TDD workflow — a disciplined five-step test-driven development
  cycle plus the judgment calls and gotchas around it.
  Language- and framework-agnostic. Use whenever writing new functionality test-first, or
  when the user says "TDD this", "test-driven development",
  "red-green-refactor", "let's do TDD", "write the test first", or asks how
  to build a test list before implementing. Also apply proactively when
  starting any feature or bugfix where tests should drive the design, not
  just verify it afterward.
allowed-tools: Read, Grep, Glob, Bash, Edit, Write
---

# TDD

A disciplined five-step cycle — not "write some tests," but a specific loop
with specific failure modes.

Before starting, inspect existing test conventions and read nearby project
context or ADRs when present.

## The cycle

1. **Sketch a short, ordered list** of the behaviors or public seams to cover.
2. **Turn exactly one item** on the list into an actual, concrete, runnable test.
3. **Change only enough code** to make the test and all previous tests pass,
   adding, reordering, or deleting list items as you learn more.
4. **Optionally refactor** the current slice to improve its design.
5. **Until the list is empty**, go back to step 2.

The most common way to get this wrong: turning every list item into a test
before making any of them pass. Don't. The list is scaffolding for your
attention, not a spec to complete before you start coding.

## Test List: short, living notes

Start with a short list of user-visible behaviors or public seams, not an
exhaustive inventory of edge cases. Let it grow, shrink, and reorder as the
implementation teaches you more. Discovering a new case mid-implementation
isn't a planning failure.

## Start at a public seam

Before writing each test, name the public seam and observable outcome under test.
Choose one seam at a time; do not design tests around private methods or internal
collaborators. For assertion and test-double guidance, see `test-principles`.

## Picking the next test

Order matters — it shapes both the coding experience and the final design.

- The first test should distinguish the intended behavior from a trivial
  implementation. Choose the smallest meaningful example that forces the design
  to take a real step; do not skip a valid simple behavior merely because it is
  simple.
- Order tests so each one forces the smallest next increment of design,
  rather than jumping straight to the hardest case.
- If a test would force you to solve two problems at once, split it — that's
  a smaller test hiding inside it.

## Interface first, implementation second

When writing a test, decide the interface first: how it's invoked, what goes
in, what comes out, and what observable result proves success. Implementation —
how the behavior gets produced — is postponed to the "make it pass" step.

## One hat at a time

"Make it pass" and "make it clean" are different steps. Get to green with only
enough production behavior to pass the current test and preserve previous tests.
Do not weaken assertions, anticipate future list items, or add speculative
behavior. Refactor separately so failures remain easy to interpret.

## Refactor with restraint

Refactoring is optional per cycle — limit it to the current slice and only do it
when it improves the design. Duplication is a hint, not a command — unify only
when it is actually costing you. Stop at "better than before," not "perfect."

## Gotchas

- Mixing implementation design decisions into the Test List step — naming the
  interface is fine, choosing the algorithm or data structure is not.
- Writing every test up front, then treating a trivial failure (a missing class
  or method, not a real assertion) as proof you're "red" — then writing all the
  implementation in one pass. One seam, one test, and one minimal implementation
  at a time; batching defeats the feedback loop.
- Abstracting too soon.

---

For test quality — public behavior, non-tautological assertions, test levels,
mocking boundaries, and framework-specific references — see the `test-principles`
skill. This skill owns the process; `test-principles` owns the quality bar for
each test.
