---
name: roadmap
description: Generate a milestone-based production roadmap through collaborative brainstorming and iterative refinement.
allowed-tools: Read, Grep, Glob, Write, Edit, Task, WebFetch, AskUserQuestion, Agent, mcp__basecamp__*
argument-hint: "[project-doc-path or Linear URL]"
user-invocable: true
auto-invoke: false
---

# Roadmap

Build a milestone-based production roadmap through conversation. This is an interview-driven skill — the user shapes every decision. Your role is to gather context, ask good questions, present options, and write what the user tells you to write.

The roadmap captures WHAT ships and WHEN — not HOW it's built. Every sentence earns its place.

## How this works

This is a back-and-forth dialogue, not a pipeline you execute. At every stage, you should be **asking questions and waiting for answers** before moving forward. The user knows their project, stakeholders, and constraints better than you do. Your job is to surface the right questions, organize the answers, and draft lean prose that reflects what was decided together.

The general shape is:
1. Gather context (you read, then summarize what you found)
2. Explore structure together (you propose options, user picks and refines)
3. Draft together (you write sections, user steers and corrects)
4. Polish (you audit for quality, user confirms cuts and changes)

But these aren't rigid phases — the conversation will naturally jump between them. Follow the user's lead. If they want to deep-dive on data model extensibility before talking about milestones, go there. If they want to start with a rough list of features and organize later, do that.

---

## 1. Gather Context

Read the project's existing materials before proposing anything. Look for:

- **Project hub/index** — team, links, status, open questions
- **Spec** — the truth document for architecture, data model, contracts
- **Meeting notes** — stakeholder feedback, demo reactions, naming decisions
- **Spike/prototype PR** — what's been validated vs. what's aspirational
- **Discovery doc** — user stories and journeys the roadmap must eventually cover

Fetch linked resources in parallel where possible.

If an existing `roadmap.md` already exists, read it — you may be iterating rather than starting fresh.

**Then stop and present a summary.** Tell the user what you found in 3-5 sentences. Ask if anything is missing or if there's context they want to add before you start proposing structure. This is your first checkpoint — don't skip it.

---

## 2. Explore Structure Together

This is a conversation, not a presentation. Your goal is to help the user think through how to slice the project into milestones.

**Start by asking questions**, not proposing answers. Good opening questions:

- "What's the thinnest slice that would prove the architecture works end-to-end?"
- "Who's the first user — internal team, hand-picked partner, or self-service?"
- "Are there features we know need design work that should be pushed later?"
- "What does the progression look like — dogfood → alpha → beta → GA, or something different?"

Based on the user's answers, present 2-3 options for milestone structure. Each option should vary on where the first milestone boundary falls, how many milestones there are, and what the audience progression looks like. Keep it brief — bullet points, not prose.

**Ask the user which direction they prefer.** They may pick one, combine elements, or propose something different. Follow their lead.

Before moving to drafting, ask:
- "Are there user stories or journeys we should cross-reference to make sure nothing falls through the cracks?"
- "Any stakeholder feedback that should shape what goes in M1 vs. later?"

---

## 3. Draft Together

Write `roadmap.md` incrementally, checking in with the user as you go. Don't write the entire document in one pass — build it section by section so the user can steer.

### Roadmap structure

**Strategy section** (2-3 paragraphs max) — The approach (e.g., skeleton → layers), key naming/terminology decisions, and the data model if relevant. Data model should include key design decisions with rationale and extensibility notes.

Ask: "Does this framing match how you'd explain the project to someone new?"

**Milestones** — The core of the document. Each milestone gets:

```markdown
### M{N}: {Name}

**Audience:** Who uses this
**Goal:** One sentence — what proves this milestone is done

**{Feature group}:**
- Feature bullet
- Feature bullet
```

Group features by domain (portal, runtime, security, firm enablement, etc.), not by implementation order. Reference user journey IDs where applicable (e.g., "_(journey 16)_").

After drafting each milestone, ask:
- "Can anything here move to a later phase? I want the first milestone especially to be as thin as possible."
- "Are there gaps — stories or journeys not covered yet?"

**Evolving role table** — Show how key personas' responsibilities change across milestones. Ask the user who the key personas are.

**Open design decisions** — Decisions that should be resolved during implementation, not upfront. Checkbox format. Ask: "What decisions are you intentionally deferring?"

**Reference section** — Links to spec, discovery doc, spike PR, project tracker, Slack channel.

### Quality checks

Run these during drafting, not as a separate pass:

- **Coverage audit**: Cross-reference user stories/journeys against milestones. Every story should land in exactly one milestone. Surface any gaps for the user.
- **Scope audit**: For each milestone, look for anything that could move later. Present candidates to the user — don't cut unilaterally.
- **Slop audit**: Every sentence should describe a feature or essential context. Flag anything that's a design note, implementation detail, or filler, and ask if it should stay.

---

## 4. Polish

Once the user is happy with the content, do a final quality pass:

- Read the full document and flag any remaining filler, hedging, or redundancy
- Check that milestone goals are concrete, not vague
- Verify the reference section links are correct
- Ask: "Anything else you want to add or cut before this is done?"

When the user says it's done:

1. **Generate a TL;DR** — 1-2 sentences summarizing what the roadmap covers, suitable for Slack. Focus on features/capabilities, not meta-description.
2. **Update project references** — Make sure the project's index/hub file links to the roadmap.

---

## Handling tangents

The user may want to deep-dive on a specific topic mid-conversation — data model extensibility, auth architecture, whether a feature belongs in M1 or M3. This is normal and valuable. Follow the tangent, help them think it through, and then bring the conversation back to where you left off. Don't rush the user back to "the process."

If a tangent produces a decision that affects the roadmap, update the draft. If it produces something that belongs in a different document (spec, discovery doc, auth clarification), suggest writing it there and referencing it from the roadmap.

---

## Anti-patterns

- **Proceeding without checking in**: Never write multiple sections without asking the user's opinion. This is a dialogue, not a monologue.
- **Implementation details in the roadmap**: No class names, file paths, or "we'll use concern X". That belongs in the spec or PR description.
- **Changelog or history sections**: The roadmap is forward-looking.
- **People/team sections**: The project index owns the team roster.
- **Hedging language**: "We might consider possibly exploring..." — either it's in a milestone or it isn't.
- **Redundant bullet points**: If two bullets say the same thing, merge them.
- **Design notes masquerading as features**: "Display names should be human-readable" is a design note. "Firm admins browse a published integration catalog" is a feature.
- **Cutting without asking**: Surface candidates for removal, but let the user decide. The user knows what's load-bearing and what's fluff.

## Philosophy

**Skeleton then layers.** Build the full end-to-end pipeline at minimum viable depth first, then layer complexity on top. The first milestone should be the thinnest possible E2E slice that proves the architecture works.

**Feature-focused, not implementation-focused.** The roadmap describes what users/partners/admins can DO, not how it's built.

**Lean and honest.** No filler, no hedging, no AI slop. "I want every sentence to be there for a reason" — that's the standard. When in doubt, ask.
