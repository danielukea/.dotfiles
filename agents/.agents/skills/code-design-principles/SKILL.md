---
name: code-design-principles
description: Principles for judging whether a code design is sound. Use when weighing a design approach or when a user says "is this well-designed?", "critique this design", "principles review".
allowed-tools: Read, Grep, Glob
---

# Code Design Principles

Durable, framework-agnostic lenses for judging whether a code design is sound. No workflow
here: pick the lenses that bear on the question and apply them to a sketch, a diff, or a
choice between two options. These sit _above_ stack-specific pattern catalogs — "how do I
factor this Rails model / React component" is `rails` or
`react-composition`; "is this approach sound, whatever the stack" is here.

---

## ETC — Easier To Change (the overriding principle)

Every other lens is a special case of this one: **good design is easier to change than bad
design.** It's the tiebreaker when two designs both work — ask which one leaves the system
easier to change when the requirement you didn't anticipate arrives.

Concrete probes:

- If this requirement shifts, how many places change? (fewer is better)
- What is coupled that shouldn't be — what knowledge is duplicated across modules?
- What is isolated well — can I replace this piece without touching its neighbors?
- What decisions are _reversible_ vs. baked in? Keep the expensive ones (database, API
  contract, framework boundary) behind a seam.

ETC is a value, not a rule.

## Tell, Don't Ask

Behavior belongs with the data it operates on — a caller that pulls state out of an object,
decides, and pushes a result back is doing the object's work. The sharpest symptom is
duplicated judgment: the same "is it valid to do X" check at every call site, because no
object owns the invariant. The fix moves the decision _to_ the data.

## SOLID — pressure-tests, not commandments

You already know the five letters; each earns its keep only where a real variation axis,
contract, or swap boundary already exists. The test for every one: does applying it here
make the system _easier to change_, or just more abstract? If it doesn't reduce future
change cost, drop it.

## Convention over configuration

Follow the patterns the codebase and framework already establish. A second way to do what
the codebase already does one way is a tax — every reader now learns two patterns, and the
new one lacks the framework's support. The burden of proof is on the _deviation_, and a
warranted new pattern gets applied consistently rather than sprinkled.

## Testability

Testable design and good design are the same thing from different angles: if a design is
hard to test, that is information about the design, not about the test. Hard-to-test is
specifically a coupling signal — too many collaborators, hidden global state, behavior
reachable only through a wide interface. Use "how would I test this?" as a probe _before_
the code exists.

## Least surprise

Another engineer should predict how this works from its shape and names without
reverse-engineering it. Watch for a side effect where none is expected, a name that lies
about what the method does, or indirection that hides the actual work. Between a clever
solution and an obvious one that's slightly longer, prefer obvious.

---

## Producing a review

Rate only the lenses that bear on the question — one line each, with the reason. The
ratings table and both verdict scales are in
[review-format.md](references/review-format.md).

## Complexity heuristic — how much process does this change deserve

Match the ceremony to the surface area. A judgment aid, not a gate.

| Signal                                           | Weight                                        |
| ------------------------------------------------ | --------------------------------------------- |
| Single file, single layer, surgical              | Just code it — no design step needed          |
| A few files, one layer, contained                | A short plan in your head or a Plan Mode pass |
| Cross-layer, several files, a real design choice | Worth a design pass (dispatch an architect)   |
| Large, multi-day, or many independent slices     | A tracked spec + plan, sliced into steps      |

When unsure, err toward _less_ process for reversible changes and _more_ for the expensive,
hard-to-reverse ones (schema, public contracts, framework boundaries).

## Gotchas

**Append new failure modes here as you hit them.**

- **No opinion on visual design.** These lenses say nothing about spacing, hierarchy,
  color, or interaction feel. If that's the question, say so and point at `frontend-design`
  — don't stretch ETC or SOLID into a critique of a UI.
- **Don't rate all six lenses mechanically.** A fixed table invites filler rows
  ("Interface Segregation: N/A"). Rate what bears on the question; a two-row review is a
  complete review.
- **Simplicity is not mediocrity.** A plain design rating "Acceptable" across the board
  beats a clever one rating "Strong" on paper. Least-surprise breaks ties _against_ the
  more abstract option — never recommend a rewrite to raise a score.
- **SOLID is for testing an abstraction, not justifying one.** Citing Open/Closed to add a
  strategy object for a variation that doesn't exist yet is the common misuse.
- **"Hard to test" is a finding, not an obstacle.** The reflex is to propose heavier mocking
  or setup to force an awkward design under test. Report the coupling as a design finding
  instead.
