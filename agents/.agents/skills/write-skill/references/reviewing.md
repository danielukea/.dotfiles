# Reviewing — auditing an existing skill

Open this when the task is *judging* a skill rather than writing one. This is the author's
principles turned around into audit questions; each points back to the reference that
teaches the rule, so fix findings there.

Run the mechanical check first (it's cheap and catches the dumb stuff), then the judgment
passes.

## Mechanical (run the linter)

- `scripts/validate_skill.sh <path-to/SKILL.md>` — frontmatter present, `name` matches the
  folder, `description` non-empty and under the 120-token ceiling, `## Gotchas` exists, and
  every `references/`/`templates/`/`scripts/` path named in the body exists on disk.

## Judgment passes

1. **Description** — near 30–40 tokens? real user trigger phrases, not internal jargon?
   a `Not for:` pointer if a sibling could collide? (→ `descriptions.md`)
2. **Gotchas** — present, led with, and non-obvious? Each should fail the senior-dev litmus
   (*would a senior dev already know this?* → if yes, cut it). A skill with none usually
   isn't teaching anything. (→ `principles.md`)
3. **DRY across layers** — does any `SKILL.md` line *re-teach* a reference instead of
   hooking to it? does any reference restate the `SKILL.md`? Redundancy is earned only as a
   hook→full-detail relationship. (→ `principles.md`)
4. **Altitude** — is `SKILL.md` on the right side of the decide/do line? Framing and
   routing stay loaded; worked examples and fill-in detail move to `references/`.
   (→ `principles.md`)
5. **Railroading** — a mandatory workflow bolted onto a judgment task, or knowledge trapped
   inside an orchestration ritual so it can't be reused? (→ `principles.md`)
6. **Portability** — hard-coded paths, commands, or repo names that belong in a project's
   rules, not in a skill meant to travel? (→ `principles.md`)
7. **Peer collision** — read the `description` beside its nearest sibling's. Could one user
   request match both? Fix with disjoint phrasings and reciprocal `Not for:` pointers.
   (→ `descriptions.md`)

## Reporting

Order findings by value: DRY/duplication and altitude problems in the always-loaded layer
cost tokens on every turn, so they outrank a stylistic nit in a reference. Point each
finding at the fix, not just the flaw.
