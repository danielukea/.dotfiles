# Descriptions — the trigger

The `description` frontmatter is how a skill gets *selected*. It is not a summary of
the contents — it's the signal an agent matches against the user's request to decide
whether to load the skill. Write it for the model, not for a human reader.

A vague description means the skill never fires. A bloated one taxes every turn.

## Start at ~30–40 tokens; grow only if it under-triggers

**Budget: begin at ~30–40 tokens. The hard ceiling is 120.** Every skill's `name` +
`description` loads into context on *every* turn, across *every* installed skill — length
is a shared, recurring cost. So start lean and spend more only on evidence the skill isn't
triggering when it should.

The fix for under-triggering is almost never "add words." It's **better trigger phrases** —
the literal things a user would say — plus a sharp `Not for:` pointer. Padding a
description to be "pushy" trades a real per-turn cost for a gain you can usually get from
phrasing alone.

## What a good description contains

1. **What it does**, in one clause. ("How to write or edit a skill well…")
2. **When to use it** — the real activation phrases a user would type. Prefer the words
   people actually say ("write a skill", "new skill") over internal jargon (the feature
   list belongs in the body/references, not the trigger).
3. **A `Not for:` disambiguation pointer** when a sibling skill could collide — naming
   the sibling. ("Not for: pruning skills — use `skill-prune`.")

## Trim order (when you're over budget)

Cut in this order, and stop as soon as you're under:

1. Redundant or near-duplicate quoted trigger phrases.
2. Verbose connective prose ("Also trigger on…", "Use whenever the user…").
3. Parenthetical elaboration that just repeats what a trigger phrase already implies.

**Never cut the `Not for: … — use X` pointers.** Those are what keep sibling skills from
firing over each other; they earn their tokens.

## Peer collision check

Before shipping a skill that sits near an existing one, put the two `description`s side
by side and read them as an agent would. If a single user request could plausibly match
both, the triggers overlap — fix it with disjoint phrasings and reciprocal `Not for:`
pointers. This seam, not the body prose, is where peer skills break.

## Examples

Focused (~35 tokens) — this skill's own description:

> How to write or edit a skill well — SKILL.md structure, triggering descriptions,
> gotchas. Use when creating, writing, editing, or reviewing a skill or SKILL.md.
> Not for: pruning skills — use `skill-prune`.

Broader knowledge skill, still trigger-first, with a disambiguation tail:

> Durable, framework-agnostic principles for evaluating software design… Use when
> weighing a design approach… or when a user says "design principles", "is this
> well-designed?", "critique this design". … stack-specific patterns live in
> `rails-composition-dhh` / `react-composition`.
