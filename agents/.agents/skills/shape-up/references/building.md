# Building technique

How a shaped concept turns into deployed work. Load this while building, not to decide whether to.

## Start from the whole concept

Keep the whole shaped concept — its appetite and boundaries — in view and let the work define its
own tasks. Work from **the concept, not a task list**: shredding it into a predetermined task list
up front loses the judgment that only shows up in the doing. (On a team this is "hand over
responsibility": give people the whole project, not tickets.)

**Imagined vs. discovered tasks.** Tasks you list up front are *imagined*; the ones that surface
only by doing the work are *discovered* — and discovered tasks are the true bulk of the project.
Expect an early stretch that's all investigation of the existing code before anything visible
happens; that's the work, not a stall.

## Get one piece done

Build one **vertical slice** wired all the way through UI-to-backend and integrate it in the
first week. Don't build horizontal layers separately — front-end-only or back-end-only work is
speculative until it's connected, and "lots of things are done but nothing is *really* done."

Pick the first slice by three criteria — **core, small, novel**:

- **Core** — central to the concept; without it the rest is meaningless.
- **Small** — finishable in a few days; if it isn't small there's little benefit to carving it off.
- **Novel** — when two candidates are both core and small, prefer the one you've never done
  before. Novel work retires the most uncertainty.

Work design and programming as a **back-and-forth on the same piece**, not a sequential handoff.
Designers hand over rough **affordances** (inputs, buttons, where data appears) — *not*
pixel-perfect screens; font, color, spacing come after the affordances are wired. Programmers
**program just enough for the next step** — scaffolding, mock data, shortcuts — rather than
building full infrastructure up front.

## Map the scopes

A **scope** is an integrated slice — bigger than a task, much smaller than the project,
finishable independently in days. **Organize by structure, not by person, role, or layer.** A
"Designers" list and a "Programmers" list produce tasks that get done without adding up to a
finished part of the project.

Scopes are *discovered, not planned* — "walk the territory before you draw the map." Early
churn (lines redrawn, scopes renamed) is normal. Signs your scopes are **right**: you can see
the whole project with nothing worrying hidden; conversations flow in the language of scopes;
new tasks have an obvious home. Signs they're **wrong** — redraw them: it's hard to say how
"done" a scope is (its tasks are unrelated); the name is generic like "front-end" or "bugs"
(a **grab bag / junk drawer** — you're not integrating enough); or it's too big to finish soon
(a mini-project with all the faults of a master to-do list).

Structural shapes: **layer cakes** (thin backend, broad UI — combine design + code in one
scope); **icebergs** (disproportionate complexity on one side — factor the other out, and
question whether the complexity is really irreducible); **chowder** (a small holding list for
loose tasks — keep it under ~3–5 items or there's a real scope hiding in it).

Mark discretionary tasks with a leading **`~`** (nice-to-have); leave must-haves unmarked.

## Show progress with the hill chart

Every scope is a dot on a hill:

- **Uphill** = figuring out the approach — *the work is unknown* (unknowns, problem-solving).
- **Downhill** = execution — *the work is known but not done*.

The hill chart beats a to-do list because to-do lists hide two things: tasks that don't exist
yet (a list grows as you discover work — an empty scope may just be unexplored), and uncertainty
(two "4-hour" tasks carry different risk; estimates only mean something at the hilltop). A dot
that hasn't moved between snapshots is a **raised hand** — jump to the specific unknown, don't
ask for status.

**Push the scarier work uphill first** (the inverted pyramid) — solve high-unknown problems
early, leave routine polish for last. **Thinking your way uphill** is the trap: declaring a
scope solved in your head, then backsliding when the unknowns are real — you're only truly
downhill once you've built enough to believe no other unknowns remain. A stuck dot often means
the scope bundles independent parts at different hill positions; split it so they move
independently.

## Decide when to stop

**Compare down to the baseline, not up to the ideal.** Judge quality against the frustrating
reality customers endure today, not against an imaginary perfect design that never ships.

**Scope hammering** — repeatedly, forcefully cutting scope to fit the time box. For each
discovered task ask: must-have for *this version*? Could we ship without it? New problem or
pre-existing? How common is this case — core or edge? Real impact? Marking a task `~` *is* the
act of hammering — a "no" that doesn't delete it. Cutting scope is not lowering quality; being
picky about what matters for the core use case is what differentiates the product.

**Extending is rare** and needs both conditions: every remaining item is a true must-have that
survived hammering, **and** all remaining work is downhill (no unsolved problems, no open
questions). Any remaining uphill work means the shaping failed — better to put the project back
into shaping than to keep pouring time in. Even when both conditions hold, prefer discipline;
habitual extensions mean bad shaping.
