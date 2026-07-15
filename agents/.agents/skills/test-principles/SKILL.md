---
name: test-principles
description: >
  Generic principles for writing and reviewing high-signal automated tests:
  test public behavior at seams, assert outcomes instead of implementation,
  mock only appropriate service boundaries, and avoid tautological, brittle,
  flaky, or over-coupled tests. Use when writing tests, doing TDD, reviewing
  specs, or deciding what to mock. Load references/ for Rails/RSpec guidance.
allowed-tools: Read, Grep, Glob, Bash, Edit, Write
---

# Test Principles

Use tests for trustworthy feedback and change-safe design. Apply these as
judgment lenses, not as a rigid workflow.

## Test the seam

Test through the smallest public interface a user or caller can observe. Assert
return values, persisted state, emitted events, HTTP responses, and meaningful
side effects. Do not reach into private methods, instance variables, call chains,
framework declarations, or database internals just to increase coverage.

If behavior is difficult to reach through a public interface, treat that as a
design signal. Extract a cohesive object with its own public contract before
testing a private method. In legacy code, a narrow characterization test or
temporary seam may be justified; do not make it the pattern for new code.

## Make every test earn its place

A test should:

- fail when the promised behavior is wrong; and
- survive a correct refactor of the implementation.

Ask what defect the test catches and what internal change should leave it
passing. Prefer one logical behavior per example, with a name that says what
happened, not how it happened. Keep setup causal, explicit, deterministic, and
small.

Expected values come from the requirement, a worked example, or an independent
invariant—not from reusing production's algorithm. Include meaningful boundary
and failure cases, especially exclusions for scopes and filters.

## Assert outcomes, not implementation

The subject owns its return value, state changes, and externally visible effects.
The receiver's tests own the meaning of a collaborator's return value. This
message-direction rule avoids duplicated assertions and interaction coupling.

Assert an interaction only when the interaction is the subject's observable
responsibility: enqueueing a job, sending mail, publishing an event, or calling
an external adapter. Do not assert internal call order, exact counts, or private
collaboration just because the implementation currently does so.

## Mock boundaries, not owned code

Use real objects for code the application owns, especially domain models and
collaborating services. Use a double when a real dependency is slow,
nondeterministic, costly, destructive, unavailable, or outside the test's
responsibility:

- external APIs, mail, queues, and processes;
- filesystem, cloud storage, and other I/O;
- time, randomness, environment, and similar nondeterministic inputs.

Do not mock an owned model or service merely for convenience. A graph of stubs
usually signals hidden coupling, too many responsibilities, or the wrong test
level. Prefer a small real collaborator, focused fake, or extracted boundary.
When a double is justified, use a verifying double where available and test the
real adapter or boundary contract separately.

## Choose the cheapest confidence

Use different test scopes without repeating every case at every layer:

- focused tests for domain decisions and transformations;
- integration tests for wiring, persistence, serialization, and adapters;
- a small number of system tests for critical user journeys lower tests cannot
  observe.

Push detailed edge cases down to the narrowest level that can prove them. Keep a
higher-level test when it adds confidence about routing, authorization, rendering,
integration, or a user-visible workflow.

## Reject false confidence

Reconsider tests that only prove a method, association, callback, column, or route
exists; stub the subject and assert the stub; duplicate a receiver's contract;
depend on factory magic; contain a mock avalanche; or pass against a broken
implementation. See [testing-smells.md](references/testing-smells.md) for the
diagnostic catalog and [rails-rspec.md](references/rails-rspec.md) for framework
patterns.

The `tdd` skill owns the red-green-refactor loop. This skill owns the quality bar
for the tests produced by that loop. Sources and provenance are in
[sources.md](references/sources.md).
