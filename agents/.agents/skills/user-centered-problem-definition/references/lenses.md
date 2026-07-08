# The six lenses — full treatment

Read this when you're actually applying a lens — SKILL.md has the summary table and the
decision heuristic; this file has the detail and the traps with worked examples. Fill-in
templates are in `templates.md`.

---

## Stakeholders — everyone the change touches, not just users

Who is affected, who decides, who pays, who has to support it. Map them by
influence/interest so you know whose needs bind the problem. Artifact: a stakeholder table
or a power/interest grid (`templates.md`).

**Gotcha:** distinguish stakeholders from users — they are not the same people, and the
loudest stakeholder (the exec, the buyer) is rarely the person who lives in the flow. A
problem framed around the stakeholder who asked for it, instead of the user who suffers it,
solves the wrong thing.

## Users / personas — the distinct kinds of people who use it

The segments who actually use the thing, each with a context and a goal. A persona is a
compression of real differences that change the design, not a cast of characters. Artifact:
a short persona card per distinct segment (context, goal, constraint).

**Gotcha:** ground personas in evidence (research, support tickets, the user's own
knowledge), never invented demographics. A persona is a decision tool — if a detail
wouldn't change a decision, leave it out. Inventing "Sarah, 34, likes yoga" adds fiction,
not signal. If you have no evidence, say so and mark it an assumption.

## Jobs / job stories — the outcome they're hiring the thing to do

What is the user trying to accomplish, in what situation, and why. Format:
**"When [situation], I want to [motivation], so I can [expected outcome]."** Job stories
capture motivation independent of any solution.

**Gotcha:** a job is an outcome, not a feature. "When a deal closes, I want the team
notified, so nobody double-works the account" is a job; "add a Slack notification" is a
solution wearing a job's clothes. Keep the situation and outcome; drop the mechanism.

## Journeys — how they move through it, and where it hurts

The stages and steps a user takes to get the job done, annotated with what they're doing,
feeling, and where they stall or drop off. This is the lens that *surfaces the problems* —
pain points and drop-offs are the raw material of the problem statement. Artifact: a stage
table (action / thought / pain per step) or a Mermaid journey/flow.

**Gotcha:** map the **current state** first — the journey as it actually happens today,
warts and all — because that's where the pain lives. A future-state "happy path" journey is
already a solution sketch and belongs later. And `brainstorm`'s Prototype gear owns the
*quick* journey sketch (a few decision points inline); come here only when the journey needs
real structure across segments and emotions — the same way `html-mockup` relates to a
throwaway ASCII wireframe.

## User stories — what each user must be able to accomplish

The actionable unit of user need, once the who/why is understood. Format:
**"As a [user], I want to [capability], so that [benefit]."** One per meaningful capability,
tied back to a job.

**Gotcha:** these are **problem-framing**, not backlog items. No acceptance criteria, no
estimates, no priority — the moment you're writing those, you're in the tracker flow, not
here. A story here answers "what must this user be able to do and why," so `arch-design` and
the tracker have something grounded to build on. Keep them at the level of user intent, not
implementation steps.

## Affordances — what the system must make possible, per step

For each journey step or job, the **capabilities the solution has to offer** a given user:
what they must be able to perceive, decide, and do to get through. This bridges need →
requirement while staying solution-neutral. Artifact: a capability checklist keyed to
journey steps.

**Gotcha:** an affordance here is a *required capability*, not a UI element. "The user must
be able to see which records are unassigned and reassign one" is an affordance; "add a
dropdown in the toolbar" is a UI decision that belongs to `arch-design`. Name what must be
possible and obvious; leave the widget, layout, and mechanism to design. If you catch
yourself naming buttons, you've crossed the line.
