---
name: design-principles
description: >
  Durable, framework-agnostic principles for evaluating and shaping software
  design — Easy To Change (ETC), Tell-Don't-Ask, pragmatic SOLID, convention
  over configuration, testability, and least surprise. Use whenever weighing a
  design or architectural approach, reviewing a proposed structure, deciding
  between two ways to factor something, or when a user says "design principles",
  "is this well-designed?", "evaluate this approach", "critique this design",
  "principles review", or "which of these is cleaner?". Also apply proactively
  when sketching your own approach before writing code — you don't need to
  dispatch anything to use these. Teaches WHAT good design optimizes for, not a
  workflow. Stack-specific patterns live in rails-composition-dhh /
  react-composition; this is the layer above them.
allowed-tools: Read, Grep, Glob
---

# Design Principles

A compact set of durable principles for judging whether a design is sound. These
are the criteria to reason *with* — apply them to a sketch, a diff, or a decision
between two options. There is no workflow here: pick the lenses that bear on the
question and use them.

These sit *above* stack-specific pattern catalogs. When the question is "how do I
factor this Rails model / React component," reach for `rails-composition-dhh` or
`react-composition`. When the question is "is this approach well-designed, whatever
the stack," use these.

---

## ETC — Easier To Change (the overriding principle)

Every other principle is a special case of this one: **good design is easier to
change than bad design.** When you weigh two approaches, ask which one leaves the
system easier to change when the requirement you didn't anticipate arrives.

Make it concrete by asking, of a proposed design:
- If this requirement shifts, how many places change? (fewer is better)
- What is coupled that shouldn't be — what knowledge is duplicated across modules?
- What is isolated well — can I replace this piece without touching its neighbors?
- What decisions are *reversible* vs. baked in? Prefer keeping expensive decisions
  reversible (the database, the API contract, the framework boundary) behind a seam.

ETC is a value, not a rule. It gives you the tiebreaker when two designs both "work."

## Tell, Don't Ask

Behavior should live with the data it operates on. A caller that pulls state out of
an object, makes a decision, and pushes a result back is doing work the object should
do itself.

```
# Ask — logic leaks into the caller
if account.balance >= amount && account.active?
  account.balance -= amount
end

# Tell — the object owns its invariant
account.withdraw(amount)   # decides and enforces internally
```

Symptoms of violation: controllers/callers reaching through an object's getters to
make decisions; the same "is it valid to do X" check duplicated at every call site;
an object exposing internal state only so callers can manipulate it. The fix moves the
decision *to* the data. This is the design-level statement of encapsulation.

## SOLID — pragmatic, not dogmatic

SOLID is a set of pressure-tests, not commandments. Apply each where it earns its
keep; don't manufacture abstractions to satisfy a letter.

- **Single Responsibility** — a module should have one reason to change. If a class
  changes for two unrelated reasons (billing rules *and* email formatting), the seam
  is wrong. But don't shred a cohesive object into anemic fragments chasing purity.
- **Open/Closed** — extend without modifying, *when* a real variation axis exists.
  Premature "pluggability" for a variation that never comes is just indirection.
- **Liskov Substitution** — a subtype must honor the supertype's contract. A subclass
  that raises on a method the parent supports is a design lie.
- **Interface Segregation** — don't force clients to depend on methods they don't use.
  Fat interfaces couple unrelated callers.
- **Dependency Inversion** — depend on abstractions at the boundaries you actually
  need to swap (external services, IO), not everywhere.

The test for every one: does applying it here make the system *easier to change* (ETC),
or just more abstract? If it doesn't reduce future change cost, skip it.

## Convention over configuration

Follow the patterns the codebase and framework already establish. A design that
invents a new way to do something the codebase already does one way is a tax: every
reader now learns two patterns, and the new one lacks the framework's support.

Ask: is there an existing convention for this (in this codebase or the framework's
idioms)? If yes, the burden of proof is on the *deviation*. New patterns are worth it
only when the existing one genuinely doesn't fit — and then the new pattern should be
applied consistently, not sprinkled.

## Testability

Testable design and good design are the same thing viewed from different angles. If a
design is hard to test, that is information about the design, not the test.

- Can the core behavior be exercised with a simple, fast unit test — or does it require
  standing up half the system?
- Does the design force integration/end-to-end tests where unit tests should suffice?
  That usually means logic is entangled with IO or framework glue that should be
  separated behind a seam.
- Hard-to-test is a coupling smell: too many collaborators, hidden global state,
  behavior reachable only through a wide interface.

Use "how would I test this?" as a design probe *before* the code exists.

## Least surprise

Another engineer should understand the design immediately. Clever is the enemy of
clear. The best design is often the boring one that the next reader predicts correctly
without having to reverse-engineer it.

- Would a competent teammate guess how this works from its shape and names?
- Does it do anything surprising — a side effect where none is expected, a name that
  lies about what the method does, indirection that hides the actual work?
- Between a clever solution and an obvious one that's slightly longer, prefer obvious.

Cleverness that saves five lines but costs every future reader a double-take is a bad
trade under ETC.

---

## Using these in a review

When critiquing a design (yours or an architect's), give each relevant principle a
one-line verdict and reason rather than prose:

| Principle | Rating | Reason |
|-----------|--------|--------|
| ETC (easier to change) | Strong / Acceptable / Weak | what couples / isolates / breaks on change |
| Tell, Don't Ask | … | does behavior live with its data? |
| SOLID (where it lands) | … | which principle bears here, and is the tradeoff worth it? |
| Conventions | … | follows established patterns or invents new ones? |
| Testability | … | fast unit tests, or forced integration tests? |
| Least surprise | … | would another dev immediately understand it? |

Close with a verdict (**Sound** / **Sound with concerns** / **Needs revision**), the
concerns worth raising before implementation, and small suggested tweaks — not a rewrite.
Don't penalize simplicity: a plain design that scores "Acceptable" everywhere and "Strong"
on least-surprise usually beats a clever one that's "Strong" on paper and opaque in practice.

---

## Complexity heuristic — how much process does this change deserve

Match the ceremony to the surface area. This is a judgment aid, not a gate.

| Signal | Weight |
|--------|--------|
| Single file, single layer, surgical | Just code it — no design step needed |
| A few files, one layer, contained | A short plan in your head or a Plan Mode pass |
| Cross-layer, several files, a real design choice | Worth a design pass (dispatch an architect / write a spec) |
| Large, multi-day, or many independent slices | A tracked spec + plan, sliced into steps |

When unsure, err toward *less* process for reversible changes and *more* for the
expensive, hard-to-reverse ones (schema, public contracts, framework boundaries).
