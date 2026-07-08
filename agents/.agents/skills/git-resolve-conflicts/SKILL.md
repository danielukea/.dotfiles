---
name: git-resolve-conflicts
description: Resolve git conflicts well during a rebase, merge, or cherry-pick. Use whenever you hit "CONFLICT (content)", need to "resolve conflicts", "fix merge conflicts", "rebase onto", "git rebase", "continue a rebase", handle a "cherry-pick conflict", or when both sides changed the same code. Teaches reading both sides before resolving, blending changes when needed, using git rerere, and doing it safely.
---

# Resolving git conflicts (rebase / merge / cherry-pick)

The failure mode this prevents: picking one side of a conflict — or naively keeping both
hunks — without reading what each side was trying to do, silently dropping work.

## 1. Before you touch a conflict — make it reversible

- Confirm a clean tree first (`git status`). Stash or commit any unrelated work; never
  start a rebase with a dirty tree.
- Drop a backup ref so the pre-op state is always recoverable:
  `git branch backup/<branch>-$(git rev-parse --short HEAD)`. (`ORIG_HEAD` also points at
  the pre-rebase/merge commit, but an explicit branch is harder to lose.)
- Escape hatch: `git rebase --abort` / `git merge --abort` / `git cherry-pick --abort`
  returns to the *exact* prior state. Use it the moment a resolution looks wrong — don't
  force through a rebase you no longer understand.

## 2. Enable rerere (idempotent)

```
git config --global rerere.enabled true
```

rerere ("reuse recorded resolution") records how you resolved each conflict and
auto-replays the same resolution when the *identical* conflict recurs — which happens
constantly across the many commits of one rebase, and across repeated rebases of the same
branch. Safe to re-run; already enabled here.

- `git rerere status` / `git rerere diff` show what it recorded.
- rerere **replays, it doesn't think** — always review an auto-applied resolution before
  staging it. A replay onto shifted surrounding code can be subtly wrong.

## 3. Understand both sides — the core judgment

For every conflicted hunk:

- Read the *whole* hunk, both sides: `<<<<<<< ours` … `=======` … `>>>>>>> theirs`.
- Establish the **intent** of each side — what change was it making, and *why*. When the
  diff alone is ambiguous, `git log`/`git show` the commits behind each side.
- **Rebase inverts the labels** from intuition: `ours` = the branch you're replaying
  *onto* (upstream), `theirs` = *your* commit being replayed. (In a plain merge it's the
  intuitive way round.) Confirm which is which before deciding anything.
- Never reflex-pick a side. Deleting a side silently discards that work.

## 4. Resolving is often a blend, not a pick

- The correct result is frequently *both* intents combined, not one hunk verbatim — e.g.
  keep upstream's renamed API call **and** your new argument to it.
- Reconstruct the intended final code by hand rather than choosing a whole hunk.
- Reserve `--ours` / `--theirs` for when one side is genuinely a full superset of the
  other — and say so explicitly rather than defaulting to it to make the conflict go away.

## 5. After resolving each file

- Re-read the resolved region so it reads coherently, then confirm no markers survived:
  `git grep -nE '^(<<<<<<<|=======|>>>>>>>)'` (empty output = clean).
- `git add <file>`, then `git rebase --continue` (or `git commit` to finish a merge).
- Before declaring the integration done, run the relevant build/tests. A resolution that
  dropped one side often still type-checks but breaks behavior.

## Gotchas

- One rebase surfaces conflicts commit-by-commit; expect the same conflict to reappear.
  rerere shines here — but verify each replay, don't rubber-stamp.
- Never `--skip` or `--force` past a conflict to silence it — `--skip` drops that commit
  entirely.
- After rebasing a shared branch, push only with `--force-with-lease` (never bare
  `--force`) so you don't clobber a teammate's new commits.
