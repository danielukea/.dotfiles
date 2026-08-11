# Evals and iteration — grow a shipped skill from real use

A skill is not done when it's written. It's a living document that gets sharper as you
see where it fails. (Writing the *first* draft is `starting-small.md`.)

## Grow from usage

- Add to the `## Gotchas` section every time you catch the skill (or its absence)
  causing a mistake. That list is the skill's compounding value.
- Prune as you go: if a section is never what the model needed, cut it (see DRY and the
  senior-dev litmus in `principles.md`).

## Iterate deliberately

- **One change at a time**, so you can tell what actually moved the behavior.
- Use the agent to debug its own instructions — when it ignored guidance, ask *why*, and
  fix the instruction rather than adding a louder one.
- Read **transcripts**, not just final outputs. The failure is usually "the skill didn't
  load," "a step was misread," or "information was missing" — each has a different fix.
- Prefer explaining *why* over piling on `ALWAYS` / `NEVER`. Rigid all-caps mandates are
  a yellow flag; a model with good context follows reasoning better than commands.

## When to write tests

Skills with **objectively verifiable** output (file transforms, data extraction, code
generation, a fixed workflow) benefit from eval cases. Skills with **subjective** output
(writing style, design taste) usually don't — judge those by reading transcripts.

## The automated eval loop

For the full draft → test → grade → iterate machinery — generating trigger-eval queries,
running with-skill vs baseline, grading, benchmarking, and the description-optimization
loop — **use the `skill-creator` skill**. It carries the scripts and schemas for that
loop; there's no reason to reproduce them here.

For the operational plumbing that lives only in the fuller narrative — usage logging
(`skill-usage.jsonl`, explicit vs inferred detection), the evals specs-vs-runs split, and
skill maintenance/bridging — see `~/.agents/docs/SKILLS.md`.

**Its trigger eval is only valid at `--num-workers 1`.** `run_eval.py` writes each run's
throwaway command as `<skill>-skill-<uuid>.md` into one *shared*
`<project_root>/.claude/commands/`, but scores a trigger only when the model picks that
run's own uuid. At N workers the model sees N identical candidates and picks one, so
measured recall collapses to ≈1/N — and `run_loop` then "improves" the description against
pure noise. The tell is recall near 1/N with precision pinned at 100%. Either drop to one
worker or drive `run_single_query` yourself with a per-run project root (verified
2026-08-11: `rails` measured 11% recall at 10 workers, 77% at one root per run).

Two things worth internalizing from that loop even when you iterate by hand:

- **Test with realistic, substantive prompts.** A skill is only consulted for tasks the
  agent can't trivially do alone, so a one-step prompt ("read this file") is a poor
  trigger test. Use multi-step requests phrased the way a real user would.
- **Select for generalization, not for your examples.** Improvements that only fix the
  handful of cases in front of you tend to overfit. Favor a clearer principle or a
  better metaphor over a fiddly special-case instruction.
