# Shaping technique

How to shape a raw idea into a rough/solved/bounded concept and write the pitch. Load this
while shaping, not to decide whether to.

## Before you start: three prerequisites

Don't shape until you have a **raw idea**, an **appetite** (the time it's worth), and a
**narrow problem definition**. A raw idea with no appetite and no boundary is not ready — the
right response to it is a soft "interesting, maybe some day," not a commitment.

**Narrow the problem to its baseline.** Ask "what's really going wrong?" — the request is
usually broader than the need. (Basecamp's canonical case: customers asked to "computerize the
calendar"; the real need was just to *see free spaces* to schedule, collapsing a ~6-month
project into something that fit the appetite.) The **baseline** is what customers do today
without the thing — design against that real pain, not a feature wishlist. Beware "grab bags"
and "2.0" initiatives ("redesign the Files section"): excitement with no specific problem,
metric, or boundary. Reframe to a concrete problem before proceeding.

## Find the elements — at the right altitude

Stay concrete enough to make progress, rough enough to avoid fixating. Two techniques:

- **Breadboarding.** Sketch interface *topology* in words, not pictures — three components:
  - **Places**: navigable destinations (screens, dialogs, menus, pages).
  - **Affordances**: things the user acts on or reads (buttons, fields, interface copy).
  - **Connection lines**: how affordances move the user between places.
  Zero visual styling. The notation surfaces real functional questions ("does Autopay pay the
  *current* invoice or *future* ones?") that neither prose nor a finished mockup exposes.
- **Fat marker sketches.** Draw with a marker so thick that fine detail is *impossible*. The
  constraint is the point: it stops premature attachment to layout before the idea is validated.

Aim for the specificity of the **rules of a game**, not a spec: narrow and directional ("2-up
monthly grid, dots for events, agenda list below"), yet open to many executions. Any specific
mockup — especially from a senior person — biases everyone downstream, who read every
incidental detail as direction. These artifacts are private and rough; they are the *input* to
de-risking, not a deliverable.

## Find and remove rabbit holes

A **rabbit hole** is an unsolved problem buried in the concept that can blow the appetite. They
are invisible until you deliberately slow down and look critically after the fast exploratory
phase — which is why shaping needs its own dedicated stage. To find them:

1. **Walk each use case slowly**, start to finish — gaps appear where you assumed a smooth path.
2. **Question each element**: does it need novel technical work? Are we assuming pieces integrate
   cleanly? Are we assuming a design solution exists that we haven't found? Are we punting a hard
   decision to the team?
3. **Check technical unknowns with an expert**, framed as exploratory ("this is just an idea,
   not ready to show anyone — what do you think?"). Ask **"is X possible *in six weeks*?"** — in
   software everything is possible but nothing is free; the bare "is it possible?" is a trap.

Then **make it solid** with three moves:

- **Patch the holes** — impose a pragmatic design compromise now rather than leaving a tangled
  knot for the team to untangle under deadline.
- **Cut back** — remove non-essential features.
- **Declare out of bounds** — explicitly state what the project won't cover. Teams expand scope
  to cover every case unless fenced in.

Exit state: as free of holes as possible — independent, well-understood parts that assemble in
known ways. De-risked and ready to write up.

## Write it up — the pitch's five ingredients

If you write the shaped work up (to decide on it, or just to have it recorded), these five
ingredients are the useful checklist — even a lightweight note benefits from covering them:

1. **Problem** — the raw idea plus a *single specific story* showing why the status quo fails.
   Establishes the baseline to test the solution against. Without it you get abstract UI debates.
2. **Appetite** — how much time it's worth and how that constrains the solution. Heads off the
   "anybody can suggest something expensive" conversation.
3. **Solution** — the core elements, presented so they're grasped immediately. A problem without
   a solution is *unshaped work* — don't carry raw research into the build.
4. **Rabbit holes** — the specific unknowns/complexities worth calling out so nobody gets stuck.
5. **No-gos** — anything intentionally excluded to fit the appetite or keep the problem tractable.

**Linchpin**: the one critical visual/design decision that must be concrete enough to make the
concept land — the single place you allow more fidelity.
