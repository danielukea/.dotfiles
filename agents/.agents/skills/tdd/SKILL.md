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

## The cycle

1. **Write a list** of the test scenarios you want to cover.
2. **Turn exactly one item** on the list into an actual, concrete, runnable test.
3. **Change the code** to make the test and all previous tests pass, adding new items to the list as you discover them.
4. **Optionally refactor** to improve the implementation design.
5. **Until the list is empty**, go back to step 2.

The most common way to get this wrong: turning every list item into a test
before making any of them pass. Don't. The list is scaffolding for your
attention, not a spec to complete before you start coding.

## Test List: living notes, not a fixed plan

Write down every scenario you can think of before you start, but expect it to
grow — discovering a new case mid-implementation isn't a planning failure.

## Picking the next test

Order matters — it shapes both the coding experience and the final design.

- The first test must force real behavior, not just look simple. If the
  simplest-looking case can be satisfied by a constant return value (e.g.
  "empty cart total is 0"), it's not a good starting test — go one step past
  it to the smallest case that forces the code to actually do something.
- Order tests so each one forces the smallest next increment of design,
  rather than jumping straight to the hardest case.
- If a test would force you to solve two problems at once, split it — that's
  a smaller test hiding inside it.

## Interface first, implementation second

When writing a test, decide the interface first: how it's invoked, what goes
in, what comes out. Implementation — how the behavior actually gets
produced — is postponed to the "make it pass" step, and can change freely
under refactoring later without the test caring.

## One hat at a time

"Make it pass" and "make it clean" are different steps. Get to green by
whatever means necessary — even a hardcoded return — then refactor
separately. Mixing the two makes it hard to tell whether a failure is a real
regression or a refactor gone wrong.

## Refactor with restraint

Refactoring is optional per cycle — only do it when it actually improves the
design. Duplication is a hint, not a command — only unify when it's actually
costing you. Stop at "better than before," not "perfect."

## Gotchas

- Mixing implementation design decisions into the Test List step — naming the
  interface is fine, choosing the algorithm or data structure is not.
- Writing tests without assertions just to get code coverage.
- Writing every test up front, then treating a trivial failure (a missing
  class or method, not a real assertion) as proof you're "red" — then writing
  all the implementation in one pass. One test at a time is the point;
  batching defeats it.
- Deleting assertions so a test pretends to pass.
- Copying the actual, computed value into the expected value — this makes a
  test that can never fail.
- Abstracting too soon.

---

For RSpec-specific test _quality_ (non-tautological tests, mocking,
structure), see the `write-tests` skill — this skill is the process; that one
is the bar for each test.
