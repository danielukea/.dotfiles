---
name: user-centered-problem-definition
description: >
  Framework-agnostic lens for defining a problem from the people's side — a structured
  map of who's involved (stakeholders vs users), what outcome they're after (jobs), how
  they move through it today (journeys), what they need to accomplish (stories), and what
  the system must make possible (affordances). Use when a problem is user-facing and the
  "who" needs real structure, or when a user says "map the users", "who are the
  stakeholders", "user journey", "user stories", "jobs to be done", "who is this for",
  "personas", or "map the affordances". Pairs with `brainstorm` (which invokes this when
  its "who feels the pain?" needs depth) and feeds the Problem Brief. Teaches WHAT to map
  and the traps, not a workflow. Not for: implementation or UI components (use
  `arch-design`), backlog tickets with estimates/acceptance criteria (use the issue
  tracker flow), or getting to a one-sentence problem fast (that's `brainstorm`).
allowed-tools: Read, Grep, Glob, AskUserQuestion
---

# User-Centered Problem Definition

A lens for the **who** and the **why**, applied while a problem is still being defined. It
turns a vague "this is for users" into a structured map: who's affected, what they're trying
to accomplish, where it hurts today, and what any solution must let them do. No workflow —
pick the lenses the problem needs and skip the rest.

It lives at `brainstorm`'s altitude (problem-space), *above* `arch-design` (solution-space):
it answers who and why, never how it's built. The moment you're naming components, files, or
widgets, you've left this skill — hand off to `arch-design`.

## The six lenses

Roughly **broad → specific** — an ordering to draw from, not a pipeline. Most problems need
two or three; a stakeholder table plus one current-state journey is often the whole job. The
full sweep is for genuinely multi-party, multi-segment problems. Stop once the "who" is clear.

| Lens | What it maps | Reach for it when | The trap |
|------|--------------|-------------------|----------|
| **Stakeholders** | Who's affected, decides, pays, supports | Competing interests, approval, funding, support burden | Centering the loudest stakeholder, not the user who suffers it |
| **Users / personas** | The distinct kinds of people who use it | Genuinely different kinds of users exist | Invented demographics instead of evidence-grounded, decision-relevant segments |
| **Jobs / job stories** | The outcome they're hiring it to do | The *why* anyone wants this is unclear | Writing a feature ("add Slack") instead of an outcome |
| **Journeys** | How they move through it, and where it hurts | Friction, drop-off, "where does it break down" | Mapping a future happy-path instead of the painful current state |
| **User stories** | What each user must be able to accomplish | Turning need into concrete capabilities | Sliding into backlog tickets — estimates, acceptance criteria |
| **Affordances** | What the system must make possible, per step | Naming requirements before design | Naming UI widgets instead of required capabilities |

Definitions, formats, and worked examples of the traps: `references/lenses.md`. Fill-in
templates: `references/templates.md`. Load them when producing a map, not to pick a lens.

## Composition — where this fits

- **`brainstorm` invokes this** when its "who feels the pain?" needs more than a one-line
  answer — this is the structured expansion of that question.
- **Output feeds the Problem Brief** (its Users & Stakeholders section), so the "who" reaches
  `arch-design` instead of evaporating. Outside a brainstorm session, render inline and offer
  to fold the map into whatever artifact the work feeds.
- **`arch-design` consumes, doesn't reproduce** — it inherits the map via the Brief. A
  user-facing design arriving with no map is the signal to run this lens first.
- **The tracker is downstream** — stories here are problem-framing; turning them into
  estimated, acceptance-criteria'd tickets is a separate step.

## Gotchas

- **No fictional evidence.** Personas, pain points, and journeys asserted without grounding
  are confident fiction. Mark assumptions as assumptions, and ask or point at where the
  evidence would come from.
- **Users ≠ stakeholders ≠ the person who asked.** Conflating the three is the most common
  way a "user-centered" definition quietly centers the wrong person.
