# Bug template

Expected vs actual _is_ the issue. A reliable repro replaces acceptance criteria — the bar is
"the repro no longer reproduces."

```md
# <the symptom — not a diagnosis unless you've confirmed it>

## Summary

<1–2 sentences: what breaks, for whom, how badly.>

## Repro

1. <from a known starting state>
2.
3.

## Expected vs actual

- **Expected:** <...>
- **Actual:** <...>

## Evidence

<Optional. Error text, stack trace, log line, screenshot, request ID.>

## Environment

<Optional. prod / staging / local; build or commit.>

## Provenance

<Optional. Where it surfaced — PR review, QA of another issue, support thread.>
```
