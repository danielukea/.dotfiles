# Problem Brief template

Write this once the problem is defined and a direction is sketched — not before. A Brief
written too early formalizes the confusion. Offer to save it as a file (suggest `BRIEF.md`
in the current directory, or ask where). It must stand alone: a teammate should understand
the problem and direction without having seen this conversation. No jargon from the session.

---

## Problem Brief: [Short Title]

### The Problem
One or two sentences. What is broken, missing, or painful, and for whom?

### Users & Stakeholders
*(Include when the problem is user-facing; omit for pure infra/tooling.)* Who is affected
and who has a stake — distinguishing the people who live in the flow (users) from those who
decide, pay, or support it (stakeholders). Name the key jobs they're trying to accomplish
and where the current experience hurts. For anything with real multi-party or multi-segment
complexity, produce this with the `user-centered-problem-definition` skill and drop the map
(or a link to it) here.

### Why Now
What's driving this? Why is it worth solving today?

### Constraints
- **Must:** (non-negotiables)
- **Should:** (strong preferences)
- **Won't:** (explicitly out of scope)

### Proposed Direction
A paragraph or two — the birds-eye view of the solution shape. Not an implementation plan,
but a clear sense of what we're building and why this approach. Name the key decisions made.

### Artifacts from This Session
List any diagrams, wireframes, or matrices produced, with a one-line description of what
each showed.

### Open Questions
Things that would change the direction if answered differently. Deferred, not forgotten.

### Next Steps
What to do with this Brief. Common:
- "Run `/arch-design` to design the implementation."
- "Break this into tracked work in your issue tracker."
- "Validate the direction with [stakeholder] before investing further."

---

Don't fake precision. If the direction isn't clear, say so in Open Questions rather than
inventing a direction to fill the template. And keep it to **one** direction — if several
approaches are worth exploring, frame them as Open Questions, not a menu of parallel
proposals. A Brief that says "we could do A or B or C" hasn't finished its job.
