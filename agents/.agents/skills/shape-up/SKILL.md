---
name: shape-up
description: Shape Up (Basecamp) shaping — appetite over estimate, fixed time with variable scope, breadboarding, vertical slices, hill charts. Use whenever how much the work is worth is still open, or a rough idea needs de-risking before commitment.
allowed-tools: Read, Grep, Glob
---

# Shape Up

A running lens for carrying a project from a rough idea through to shipped work — **shape →
plan → build** — without runaway scope. The central idea: **fixed time, variable scope** —
decide how much time the work is worth up front, then shape the work to fit, rather than
estimating an open-ended scope. Two activities carry most of the value: **shaping** work to
the right level of abstraction before starting, and **building** it as integrated vertical
slices organized into scopes. You should fully understand the problem and the user needs. Shaping
helps determine how to meet those needs.

---

## The core reframes

The value here is these inversions of normal planning — get them and the rest follows.

- **Appetite, not estimate.** Estimates start with a design and end with a number; appetites
  start with a number and end with a design. The time budget is a _creative constraint_ set
  before design, not a prediction derived after it. Rough sizes: a small piece (~1–2 weeks)
  vs. a big one (up to ~6 weeks).
- **Fixed time, variable scope.** The budget is fixed and scope flexes to meet it. When the
  work is too big, **narrow the problem** — don't extend the time.
- **Shape before you commit.** Don't start work that hasn't been shaped and de-risked. A rough
  problem with no worked-out solution just pushes the unknowns into the build, where a fixed
  budget can't absorb them. Ideas that aren't ready get a soft "maybe later," not a commitment.
- **Overrun is a signal, not a reason to extend.** When work won't fit, the default move is to
  cut scope, not add time. Blowing the budget usually means the shaping missed a rabbit hole —
  re-shape it rather than pour in more time.

---

## The two activities

| Activity  | Produces                              | Key moves                                                                                                                                                                                  | The trap                                                                                                                                                                          |
| --------- | ------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Shape** | A _rough, solved, bounded_ concept    | Set the appetite; narrow the problem to its baseline; breadboard/sketch the elements at the right altitude; hunt rabbit holes and de-risk _before_ committing                              | Over-specified mockups that box in the implementation; committing to a problem with no worked-out solution; asking "is it possible?" instead of "possible in the time we have?"   |
| **Build** | Deployed work — _done means deployed_ | Take the whole shaped concept, not a task list; get one core/small/novel slice integrated end-to-end early; map scopes by structure; track on the hill chart; hammer scope to fit the time | Shredding the concept into tasks up front; scopes organized by role or layer ("grab bags"); "thinking your way uphill"; comparing up to the ideal instead of down to the baseline |

Shaping technique (breadboarding, rabbit-hole hunting, and the pitch format if you write one
up): `references/shaping.md`. Building technique (the one-piece test, scope shapes, hill chart,
scope hammering, when to stop): `references/building.md`. Load these when doing the work, not
to understand the concepts.

## Scopes → issues & prototypes

- **One scope ≈ one issue.** A scope is an independently finishable, integrated slice — the
  right grain for an issue. Leave must-haves unmarked and prefix `~` on nice-to-haves so the
  cut line is visible. The grab-bag test applies to an issue list too: "front-end" or "bugs"
  as an issue means you haven't sliced by structure yet.
- **Prototype to de-risk, before committing.** Breadboard the flow (places / affordances /
  connections — see `references/shaping.md`) or build a real-HTML mockup with the `html-mockup`
  skill to answer an open question, rather than writing issues around an unproven idea.

---

## Gotchas

- **Shaped work has three properties: rough, solved, bounded** — not "solid," and not four.
  _Rough_ leaves room for the implementer; _solved_ means the main elements connect and known
  rabbit holes are removed; _bounded_ means the appetite and out-of-bounds are stated. Rough is
  not unsolved.
- **A hill-chart dot that doesn't move is a raised hand.** It signals a hidden unknown, not
  laziness. Find what's blocking, don't just ask for a status.
- **Scope grows like grass.** Growth is natural, not a failure — you can't see the micro-detail
  until you're in the work. Manage it with continuous cutting (scope hammering), don't try to
  prevent it.
- **QA and code review are level-ups, not gates.** Own basic quality as you build (write your
  own tests); use QA/review to find edge cases, not as a checkpoint all work must clear to ship.
- **A bug is not an excuse to interrupt.** Most bugs can wait. Significant ones get shaped and
  prioritized like anything else; dropping everything to fix one costs more than it looks.
- **After shipping, let the storm pass.** Releases beget requests. Raw feedback is unshaped — a
  gentle "no" now, then re-shape the worthwhile parts before committing to them. Saying yes on
  the spot is taking on debt.
