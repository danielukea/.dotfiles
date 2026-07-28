# Review format

The output shape for a principles review. Load this when you're actually producing one —
the lenses themselves are in `SKILL.md`.

## Ratings table

One row per lens that bears on the question. **Omit the rest** — a two-row table is a
complete review, and a row reading "N/A" is noise. Give the reason, not a restatement of
the principle.

| Principle              | Rating                     | Reason                                                    |
| ---------------------- | -------------------------- | --------------------------------------------------------- |
| ETC (easier to change) | Strong / Acceptable / Weak | what couples / isolates / breaks on change                |
| Tell, Don't Ask        | …                          | does behavior live with its data?                         |
| SOLID (where it lands) | …                          | which letter bears here, and is the tradeoff worth it?     |
| Conventions            | …                          | follows established patterns or invents new ones?         |
| Testability            | …                          | fast unit tests, or forced integration tests?             |
| Least surprise         | …                          | would another dev immediately understand it?              |

## Verdict scales

Pick the scale that matches what you're reviewing:

- **A design or proposed approach** — `Sound` / `Sound with concerns` / `Needs revision`
- **A diff or branch** (changes already written) — `Ship` / `Ship with tweaks` /
  `Refactor before shipping`

## Closing the review

After the verdict, give:

- The concerns worth raising before implementation — or the top 3 for a diff.
- Small suggested tweaks. **Not a rewrite.** If the design is sound but plain, say so and
  stop; scoring "Acceptable" across the board with a "Strong" on least-surprise is a pass,
  not a mandate to add abstraction.

For a diff review, evaluate the changes as written — whether they leave the code easier or
harder to change than before — rather than proposing an alternative design.
