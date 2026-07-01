# Pragmatic Programmer Principles — Shared Vocabulary

Every extensibility-focused lens cites this file when justifying severity.
Using one shared vocabulary keeps the report consistent instead of relying
on ad-hoc adjectives.

Source: *The Pragmatic Programmer*, 20th anniversary edition (Hunt & Thomas,
2019). The 2nd edition added **ETC** as the meta-principle.

## North star: ETC — Easier to Change

> Every design decision should leave the code easier to change than it was
> before. When two designs achieve the same behavior, the one that leaves
> more options open wins.

Use ETC as the deciding heuristic in every finding's `Direction` field.
A "better" design that is harder to change is the wrong call.

## The composition principles

### DRY — Don't Repeat Yourself

> Every piece of *knowledge* must have a single, unambiguous, authoritative
> representation within a system.

**Important distinction:** DRY is about duplicated *knowledge*, not duplicated
*code*. Two functions with identical bodies expressing different domain rules
are not a DRY violation — they will diverge for the right reason. The
duplication lens enforces this distinction.

**Lens that uses it:** Duplication.
**Connascence link:** CoA (algorithm) and CoM (meaning).

### Orthogonality

> Eliminate effects between unrelated things.

Components should be independent: a change in one should not require a
change in another. Temporal coupling in git history (files that always change
together) is the empirical signal that orthogonality is missing.

**Lenses that use it:** Coupling, Vertical-slicing.
**Connascence link:** A symptom of high cross-module connascence.

### Reversibility

> There are no final decisions.

Defer commitment behind variation points, abstractions, and configuration so
the project can change direction without rewriting. Hard-coded providers,
un-versioned wire formats, and ad-hoc enums in production tables are
irreversibility traps.

**Lenses that use it:** Variation points, Contract surface.

### Tracer Bullets

> Build a thin end-to-end slice that proves the architecture, then thicken it.

The philosophical ancestor of Vertical Slice Architecture. A codebase whose
features exist as thin end-to-end slices (controller → service → query →
view → test) is structured for change. A codebase where features are
scattered across layer folders is not.

**Lens that uses it:** Vertical-slicing.

### Decoupling / Law of Demeter

> Talk only to your immediate friends.

Long method chains (`a.b.c.d.foo()`), `delegate :x, to: :y.z`, and reaching
through multiple objects to retrieve state are all CoN at high locality. Each
hop in the chain is another site that breaks if intermediate types change.

**Lenses that use it:** Coupling, Connascence-tagged findings everywhere.
**Connascence link:** CoT and CoN at across-modules locality.

### Design by Contract (DbC)

> Specify preconditions, postconditions, and invariants explicitly.

A module without a contract is a module whose callers are guessing. Schemas,
type signatures, RBS / Sorbet, runtime validators, and OpenAPI specs are all
contracts. Their *absence* on a public surface is the finding.

**Lens that uses it:** Contract surface.

### Temporal Coupling

> Beware of dependencies on order or timing.

Required setup steps, "call this method first," async race windows, and
position-dependent middleware are all temporal coupling. The fix is to
compose at construction time (DI, builder), not at call time.

**Lenses that use it:** State, Connascence (CoE/CoTime).

### Configuration

> Externalize what is likely to change.

What's hard-coded that should be config? What's config that should be code
(over-configuration is also a smell)? Both directions are findings.

**Lens that uses it:** Variation points.

### Don't Program by Coincidence

> Know *why* your code works, not just *that* it works.

The agent reading the code should be able to explain why each line is
correct. If "I think this works because…" is the best the reader can do,
that's a finding — implicit invariants are time bombs.

**All lenses use this as a heuristic.**

### Transformations / Pipelines

> Model code as data flowing through transformations, not objects accreting
> state.

Transformation-shaped code (input → pure function → output → next pure
function → output) is composable. Accretion-shaped code (mutate self,
mutate dependencies, return) is not. Long methods that mutate four
collaborators are accretion smells.

**Lenses that use it:** State, Duplication (when the same transformation is
re-implemented).

### Code That's Easy to Test

> If it's hard to test, the design is wrong.

Untested complex code amplifies all other connascence: changes can't be
verified locally, so they ripple. The StinkScore harness
(`hotspot-harness.md`) weights this directly via the
`(1 − coverage)` factor.

**Lenses that use it:** Errors, State.

## How to cite this in a finding

In the `Direction` field of a finding, write:

> **Pragmatic principle:** {principle name}. {one-sentence justification of
> why the suggested direction follows from this principle.}

Examples:
- *"Pragmatic principle: Orthogonality. The fee-calculation logic should
  live in one place so a tax-rule change doesn't require two coordinated
  edits."*
- *"Pragmatic principle: Reversibility. Hard-coding `"stripe"` as the
  provider closes a door we'll need to open when finance asks for a second
  processor. Replace with a registry."*
- *"Pragmatic principle: Tracer Bullets. The notifications feature is
  scattered across six layer folders. Collapse to one slice so a future
  channel can be added in one place."*
