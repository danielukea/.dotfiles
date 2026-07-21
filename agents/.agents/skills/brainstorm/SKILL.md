---
name: brainstorm
description: Collaborative brainstorming and problem-definition session. Gathers context, interviews you through structured questioning, generates prototypes (Mermaid diagrams, ASCII wireframes, decision matrices), and synthesizes a Problem Brief defining the problem and solution direction. Use when you say "brainstorm", "help me think through", "I have an idea", "let's explore", "whiteboard this", "rubber duck", or want to sharpen a vague idea before committing to a design. Not for: architecture (use arch-design), factual research (use deep-research), or implementation planning.
allowed-tools: Read, Write, Bash, AskUserQuestion, WebFetch
---

# Brainstorm

Move a fuzzy idea to a **Problem Brief** — a saved, shareable artifact defining what we're
solving and sketching the direction. The Brief is the handoff to `arch-design`.

Four gears — **orient, sharpen, prototype, synthesize** — are a toolkit, not a pipeline.
Match the ceremony to the surface area: a clear idea might need two gears in 10 minutes; a
tangled one might cycle through all four twice. Don't run gears you don't need.

## Orient — what do we know
Read whatever context is given (fetch a URL/file, reflect back an inline description, or ask
for a seed idea). State what you understand and what's unclear — this surfaces wrong
assumptions early.

## Sharpen — interview until the problem snaps
- **Why before what.** "Why does this matter now? Who feels the pain?" before "What should
  it do?" The solution space opens once the problem is real and owned. When "who feels the
  pain?" needs more than a one-line answer — multiple user types, stakeholders vs users,
  journeys with real friction — expand it with the `user-centered-problem-definition` skill
  and carry the map into the Brief's Users & Stakeholders section.
- **Separate problem from solution.** If they're pitching a solution, surface the problem
  underneath — solutions anchor too early and close off better approaches.
- **One question at a time.** Each answer steers the next — don't batch a questionnaire.
  Plain questions for open-ended; `AskUserQuestion` for a structured choice. If they have
  momentum, get out of the way.
- **Map constraints near the end:** hard ("what can't we change?"), soft ("what would we
  prefer to avoid?"), success ("how do we know it worked?").
- **Stop when you can state the problem in one sentence they'd nod at.**

## Prototype — make something concrete
Build a rough artifact to be wrong quickly — a wrong diagram reveals hidden assumptions
faster than five more questions. You can prototype mid-interview.

| Situation | Prototype |
|-----------|-----------|
| Flow / process / sequence | Mermaid flowchart or sequence diagram |
| State machine / lifecycle | Mermaid state diagram |
| UI layout or screen | ASCII wireframe or structured section list |
| Visual look & feel of a UI surface | `html-mockup` skill (real HTML, grounded in the actual design system) |
| Data model / relationships | Mermaid ER or class diagram |
| Options comparison | Decision matrix (markdown table) |
| User journey | Step-by-step narrative with decision points |
| Users, stakeholders, or a structured journey | `user-centered-problem-definition` skill (maps who's involved and what they need) |
| Hierarchy or taxonomy | Indented outline |

**Ground UI prototypes in the real surface.** If what you're sketching already exists in the
codebase, read its actual components and styles before drawing — a wireframe or mockup that
invents a generic design language (or guesses at a house style from memory) isn't a prototype
of the thing, it's a prototype of something else. A few real component files are usually
enough to borrow the actual vocabulary — class names, spacing, component names — rather than
approximate it.

Write prototypes inline by default (Mermaid renders as a code block; ASCII renders directly).

**Optional live preview.** When a prototype would be genuinely clearer *seen than read* — a
diagram, a layout, side-by-side options — you can render it in the user's browser with a
tiny live-reload server that draws Mermaid and markdown for real. It's a tool, not a mode:
offer it just-in-time, never upfront, and keep text-shaped questions in the terminal. To use
it, read `references/visual-preview.md`.

## Synthesize — write the Problem Brief
Once the problem is defined and a direction sketched, write the Brief and offer to save it
(suggest `BRIEF.md` in cwd, or ask). Template and rules: `references/brief-template.md`.

## Gotchas
- **Resist the pull into planning.** Once the problem is sharp, momentum wants to keep going —
  sketch the data model, list the PRs, write the tickets. That's `arch-design`'s job. If you
  notice yourself enumerating concrete implementation steps, that's the signal to close the
  Brief now and name `arch-design` as the next step, not to keep drafting.
- **Three rounds of questions with no prototype → make a diagram.** Show, don't ask.
- **Don't anchor the solution during sharpening.** Keep the problem frame open until the real
  constraint or pain surfaces.
- **Don't write the Brief early.** A Brief written before the problem is defined formalizes
  the confusion. And don't fake precision — put unknowns in Open Questions.
- **The Brief is for them, not you.** Shareable and standalone, no session jargon.
- **Save to cwd or ask** — this is a portable skill; don't assume a project path.
