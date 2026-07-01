# Connascence

Connascence (Page-Jones, 1992) is the rubric this skill uses to *measure* how
hard a piece of code will be to change. Every extensibility-focused finding
tags `{form, locality, degree}` so synthesis can rank by
`strength × locality × degree`.

## The forms — exact strength values

Use these exact numbers. Every lens must apply the same multipliers.

### Static (visible at the source) — easier to fix

| Form | Symbol | Strength | Description | Refactor target |
|------|--------|----------|-------------|-----------------|
| **Name** | CoN | **1** | Two sites must agree on a name | Rename — IDE catches it |
| **Type** | CoT | **2** | Two sites must agree on a type | Static types catch most |
| **Meaning** | CoM | **3** | Magic numbers/strings shared by convention | Replace Magic Number with Symbolic Constant |
| **Position** | CoP | **4** | Sites must agree on argument order | Replace positional with named/keyword args |
| **Algorithm** | CoA | **5** | Two sites must implement the same algorithm | Extract Method/Class; single owner |

### Dynamic (only visible at runtime) — harder to fix

| Form | Symbol | Strength | Description | Refactor target |
|------|--------|----------|-------------|-----------------|
| **Execution** | CoE | **6** | A must run before B | Compose at construction time; pipeline |
| **Timing** | CoTime | **7** | Race-prone ordering across threads | Synchronize, use immutable data, queues |
| **Value** | CoV | **8** | Coordinated values across modules (e.g. two enums must stay in lockstep) | Single source of truth, generated code |
| **Identity** | CoI | **9** | Sites share a mutable reference | Make immutable; remove shared state |

## Locality multiplier

Connascence at distance is exponentially worse than connascence in the same
function. Use these exact values.

| Locality | Multiplier | Definition |
|----------|-----------|------------|
| Same function / method body | 1 | Two sites in one function |
| Same class / object | 2 | Two methods on the same class |
| Same module / file | 3 | Two functions in the same file |
| Across modules within a slice | 5 | Different files, same feature folder / namespace |
| Across slices / packages | 8 | Different feature folders, same process |
| Across stacks (in-process polyglot) | 8 | Same process, different language layer (e.g. Rails ↔ React types in one app) — same multiplier as across-slices because deploys are coupled |
| Across services / network boundary | 13 | Different processes, network in between — backwards-compat is mandatory |

**For polyglot apps:** *across-stacks* applies when the languages are deployed
together (the typical Rails + React monolith). It is not the same as
*across-services*; both sides ship in one release. Use 13 only when there
is a real network boundary (mobile app calling an API, microservice).

## Degree multiplier

Degree = number of sites that must agree. A CoA between two methods is bad;
between twelve methods it's a redesign. Use the raw count.

## Severity formula

```
severity = form_strength × locality × degree
```

Use the exact tables above. **Always show both the score and the qualitative
bucket** in findings:

| Score | Bucket |
|-------|--------|
| 1 – 30 | low |
| 31 – 120 | medium |
| 121 – 400 | high |
| 401+ | critical |

Examples:
- CoA (5) at across-modules (5), degree 3 → 75 → **medium**
- CoV (8) at across-stacks (8), degree 3 → 192 → **high**
- CoI (9) at across-services (13), degree 4 → 468 → **critical**

The skill's report ranks findings by score and surfaces the highest-severity
ones first.

## Two reduction principles

1. **Convert strong forms to weaker forms.** A magic-string CoM becomes CoN
   when extracted to a constant. A CoA becomes CoN when both sites call the
   same method.
2. **Pull connascence closer.** A cross-slice CoA at locality=8 is much worse
   than the same CoA inside one class at locality=2. Vertical slicing
   (see `vertical-slicing.md`) is the technique for collapsing locality.

## How lenses tag findings

Every finding from an extensibility-focused lens includes one line in this
exact format:

```
**Connascence**: {Form} ({strength}) at {locality} (×{mult}), degree {n} → {score} ({bucket})
```

Examples:
- `**Connascence**: Algorithm (5) at across-slices (×8), degree 3 → 120 (medium)`
- `**Connascence**: Position (4) at same-class (×2), degree 7 → 56 (medium)`
- `**Connascence**: Identity (9) at across-modules (×5), degree 4 → 180 (high)`

The synthesis step groups findings by form and computes the running severity
total per area of the codebase. Showing the formula inline lets the synthesis
tool (or the human) verify and aggregate scores directly.

## When the rubric does *not* apply

- Connascence describes inter-element dependencies. A 200-line method with no
  cross-element coupling is a complexity problem, not a connascence problem
  — the complexity & churn lens owns it.
- Connascence is silent on missing abstractions. The variation-points and
  extensibility lenses cover "what's not there but should be."

## References

- Meilir Page-Jones, *What Every Programmer Should Know About Object-Oriented
  Design* (1995) — original taxonomy
- [connascence.io](https://connascence.io/) — concise modern reference
- Jim Weirich's "Connascence" talks — practical Ruby examples
