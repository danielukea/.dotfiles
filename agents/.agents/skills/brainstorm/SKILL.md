---
name: brainstorm
description: >
  Collaborative brainstorming and problem definition session. Gathers context, interviews
  you through structured questioning, generates prototypes (Mermaid diagrams, ASCII
  wireframes, decision matrices, outlines), and synthesizes a Problem Brief — a saved
  artifact defining the problem and birds-eye solution direction. Use when you say
  "brainstorm", "help me think through", "I have an idea", "let's explore", "I'm not
  sure how to approach", "whiteboard this", "rubber duck", or when you want to sharpen
  a vague idea before committing to a design or implementation. Not for: code review
  or architecture (use arch-design once the problem is defined), factual research
  (use deep-research), or detailed implementation planning.
allowed-tools: Read, Bash, AskUserQuestion, WebFetch
---

# Brainstorm

A structured brainstorming session that moves from a fuzzy idea to a **Problem Brief** — a
saved, shareable artifact defining what we're solving and sketching the direction. The Brief
is the handoff to `arch-design`.

The session has four gears: **orient**, **sharpen**, **prototype**, **synthesize**. These are
a toolkit, not a pipeline. A quick idea might touch only two gears; a tangled product question
might cycle through all four twice. Match the ceremony to the surface area — a clear problem
and a crisp prototype might be enough in 10 minutes; a messy, constraint-heavy problem might
need more.

## Orient — what do we know

Read whatever context the user provides:
- **URL or file:** fetch/read it, then summarize in 2-3 sentences naming the known unknowns
- **Inline description:** reflect it back and name what feels fuzzy
- **Nothing yet:** ask for a seed idea in plain conversation

State what you understand and what's unclear. This surfaces wrong assumptions early and
tells the user whether you're starting from the same place they are.

## Sharpen — interview until the problem snaps

Dig into the problem. Principles:

**Ask WHY before WHAT.** "Why does this matter now?" and "Who feels the pain?" before "What
should it do?" The solution space opens up when the problem is real and owned by someone.

**Plain questions and AskUserQuestion are both fine.** Open-ended questions ("Tell me more
about the pain here") work better as plain text; structured choices work better as
AskUserQuestion. Don't over-index on the tool.

**One round at a time.** Max 3-4 questions per round. Don't interrogate. If the user has
momentum, get out of the way.

**Separate problem from solution.** If the user is pitching a solution, surface the
underlying problem: "That's one way to solve it — what's the core problem driving it?"
Solutions anchor too early and close off better approaches. Keep the problem frame open.

**Map constraints near the end.** Once the problem is taking shape:
- Hard constraints: "what can't we change or violate?"
- Soft constraints: "what would we prefer to avoid?"
- Success: "how do we know this worked?"

**Stop when the problem snaps.** You have enough when you can state the problem in one
sentence that the user would nod at.

## Prototype — make something concrete

Build a rough artifact that sharpens the idea or tests an assumption. The point is to be
wrong quickly — a wrong diagram reveals hidden assumptions faster than five more questions.

| Situation | Prototype |
|-----------|-----------|
| Flow / process / sequence | Mermaid flowchart or sequence diagram |
| State machine / lifecycle | Mermaid state diagram |
| UI layout or screen | ASCII wireframe or structured section list |
| Data model / relationships | Mermaid ER or class diagram |
| Options comparison | Decision matrix (markdown table) |
| User journey | Step-by-step narrative with decision points |
| Hierarchy or taxonomy | Indented outline |

Write prototypes inline in the conversation. Mermaid renders as a code block here (source
the user can paste into a renderer); ASCII wireframes render directly.

You can prototype mid-interview. A rough diagram mid-session often unlocks the next question
better than asking it directly.

## Synthesize — write the Problem Brief

Once the problem is defined and a direction sketched, produce the Brief. Offer to save it
as a file — suggest `BRIEF.md` in the current directory, or ask where. The Brief is meant
to be shareable: something a teammate could read without this conversation and understand
the problem and direction. Prototypes can be included by reference or pasted in.

Template:

---

## Problem Brief: [Short Title]

### The Problem
One or two sentences. What is broken, missing, or painful, and for whom?

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
List any diagrams, wireframes, or matrices produced, with a one-line description of what each showed.

### Open Questions
Things that would change the direction if answered differently. Deferred, not forgotten.

### Next Steps
What to do with this Brief. Common:
- "Run `/arch-design` to design the implementation."
- "Break this into tracked work in your issue tracker."
- "Validate the direction with [stakeholder] before investing further."

---

Don't write the Brief until the problem is actually defined. A Brief written too early
formalizes the confusion.

## Gotchas

- **If you've asked three rounds of questions without prototyping anything, make a diagram.**
  Show, don't ask.
- **Don't anchor the solution during sharpening.** Keep the problem frame open until the
  real constraint or pain surfaces.
- **Don't fake precision.** If the direction isn't clear, say so in Open Questions rather
  than inventing a direction to fill the template.
- **One direction, not a menu.** If multiple approaches are worth exploring, frame them as
  open questions, not parallel proposals. A Brief that says "we could do A or B or C"
  hasn't finished its job.
- **The Brief is for them, not you.** Shareable and standalone — no jargon from this session.
- **Save to cwd or ask.** Don't assume a project-specific path; this is a portable skill.
