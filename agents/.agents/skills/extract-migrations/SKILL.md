---
name: extract-migrations
description: User-invoked skill (/extract-migrations) — extracts the database migrations out of a feature branch into their own PR and stacks the app code on top. Produces a safe, correct stack: expand migrations at the base, application code stacked on top, and any contract migrations stacked above the app, following strong-migrations expand/contract ordering. Only invoke when the user explicitly runs /extract-migrations. Not for generic PR-size splitting — use `wealthbox:split-pr` for that.
---

# extract-migrations

Turn one feature branch that mixes migrations and application code into a **safe, correct
stack of PRs**. Migrations go in their own PR(s); the app code is stacked on top. The ordering
follows the expand/contract rule so each PR deploys without breaking the code running before
it — see the **`strong-migrations`** skill for the full rule set (this skill assumes it).

## The stack this produces

```
master
  └─ PR 1  <feature>-migrations     expand/inert migrations + schema dump   (base ← master)
       └─ PR 2  <feature>           application code                        (base ← PR 1)
            └─ PR 3  <feature>-contract   contract migrations, if any       (base ← PR 2)
```

- **PR 1 (base)** — only *expand/inert* migrations, plus the schema dump. Deployable alone
  with zero production impact (nothing references the new schema yet).
- **PR 2 (app)** — the application code, stacked on PR 1. Its diff must show **zero**
  schema-dump changes; a dump diff here means the split leaked.
- **PR 3 (contract)** — only when the branch has migrations that must deploy *after* the app
  stops using the old schema. Stacked on top of PR 2.

## Classify each migration

The split decision is expand vs contract. When unsure, invoke `strong-migrations`.

| Layer | Goes in | Examples |
|-------|---------|----------|
| **Expand** (inert, deploy before app) | PR 1 (base) | `add_column`, `add_index … concurrently`, `add_foreign_key validate: false`, `add_check_constraint validate: false`, `create_table` |
| **Contract** (deploy after app) | PR 3 | `remove_column` (after `ignored_columns`), `validate_foreign_key` / `validate_check_constraint`, `change_column_null false` after backfill, `drop_table` |

## Recipe (execute, but confirm the plan first)

Resolve the environment, don't hardcode it:

```bash
BASE=$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's,^origin/,,')  # e.g. master
BASE=${BASE:-master}
FEATURE=$(git rev-parse --abbrev-ref HEAD)
DUMP=$([ -f db/structure.sql ] && echo db/structure.sql || echo db/schema.rb)
```

1. **List and classify migrations, then STOP and show the plan.**
   ```bash
   git diff --name-only "$BASE"...HEAD -- db/migrate
   ```
   Classify each file expand/contract, print the proposed stack (branch names, which
   migrations land in which PR), and **wait for the user to confirm** before touching git.

2. **PR 1 — base (expand migrations + dump).**
   ```bash
   git switch -c "$FEATURE-migrations" "$BASE"
   git checkout "$FEATURE" -- db/migrate/<expand files...> "$DUMP"
   ```
   **Run the guard below before committing.** Only once it passes:
   ```bash
   git commit -m "Add migrations for <feature>"
   git push -u origin "$FEATURE-migrations"
   gh pr create --base "$BASE" --head "$FEATURE-migrations" --draft
   ```
   If contract migrations exist, do **not** copy `$FEATURE`'s dump verbatim — see the guard.

3. **PR 2 — app, stacked on the base.** Rebase the feature branch onto the migrations branch;
   the identical migration hunks drop automatically.
   ```bash
   git rebase --onto "$FEATURE-migrations" "$BASE" "$FEATURE"
   # If $DUMP conflicts, take the base branch's version (app commits shouldn't touch it):
   #   git checkout "$FEATURE-migrations" -- "$DUMP" && git add "$DUMP" && git rebase --continue
   git push -f -u origin "$FEATURE"
   gh pr create --base "$FEATURE-migrations" --head "$FEATURE" --draft
   ```

4. **PR 3 — contract migrations (only if any), stacked on the app.**
   ```bash
   git switch -c "$FEATURE-contract" "$FEATURE"
   git checkout <original-feature-ref> -- db/migrate/<contract files...>
   # Regenerate the dump on THIS branch (do not copy — see the guard), run the guard, then:
   git commit -m "Add contract migrations for <feature>"
   git push -u origin "$FEATURE-contract"
   gh pr create --base "$FEATURE" --head "$FEATURE-contract" --draft
   ```

## Guard: nothing but the migrations (no drift, no leaks)

Run this on every migration branch (`$FEATURE-migrations` and `$FEATURE-contract`) **before
committing**. It fails when anything beyond the intended migrations and their exact dump delta
snuck in — the most common cause being **schema drift** in a dump generated from a dirty dev DB.

1. **File allowlist.** The only changed paths may be the intended `db/migrate/*` files and
   `$DUMP`:
   ```bash
   git diff --name-only "$BASE"...HEAD
   ```
   Any other path (a stray model, an unrelated dump, `db/seeds.rb`) is an unrelated change —
   `git checkout "$BASE" -- <path>` to drop it.

2. **Version list matches exactly.** The migration versions added to the dump must equal the
   timestamps of the included migration files — no more, no fewer:
   ```bash
   # versions the dump gained (structure.sql):
   git diff "$BASE" -- "$DUMP" | grep -oE "^\+.*\('([0-9]{14})'\)" | grep -oE "[0-9]{14}" | sort
   # timestamps of the migration files you included:
   ls db/migrate | grep -oE "^[0-9]{14}" | sort   # scope to the included files
   ```
   (For `db/schema.rb` the equivalent is the single `define(version: …)` line — confirm it
   moved to this branch's latest migration, not past it.) A **stray version** means another
   worktree's migration leaked into your dev DB — this is exactly the `/sprout-sync` drift.

3. **No unrelated schema churn.** Every remaining hunk in `git diff "$BASE" -- "$DUMP"` must
   trace to an included migration. Reordered tables, dropped/added extensions, `sequence`
   ownership churn, or `ar_internal_metadata` changes with no corresponding migration = the
   dump came from a drifted DB.

**Fix when the guard fails:** don't hand-edit the dump. Regenerate it cleanly — sync the dev DB
to `$BASE` (`/sprout-sync`), then run **only** this branch's migrations and re-dump:
```bash
git checkout "$BASE" -- "$DUMP"      # start from the base dump
bin/rails db:migrate                  # applies just the migrations present on this branch
git add "$DUMP"                       # re-run the guard; it should now be clean
```

## Gotchas

- **The schema dump travels with the migrations that produce it.** After the split, the app
  PR's diff must show **zero** changes to `$DUMP`. If it shows any, migrations leaked into the
  app branch — fix the rebase. (The migration branches themselves are checked by the guard.)
- **A backfill that references a model** (`User.in_batches { … }`) depends on app code — it
  cannot live in the app-free base PR. Keep model-referencing backfills with or above the app
  code, never in PR 1.
- **Retarget after each merge.** When PR 1 merges into `$BASE`, GitHub auto-retargets its
  immediate child, but you still must `git rebase "$BASE"` the app branch (and cascade the
  same retarget + rebase up to PR 3). After rebasing, `gh pr edit <app-pr> --base "$BASE"` if
  GitHub didn't already.
- **One statement per `disable_ddl_transaction!` migration** (from `strong-migrations`) — never
  merge or split migration *files* to make the layers balance; move whole files only.
