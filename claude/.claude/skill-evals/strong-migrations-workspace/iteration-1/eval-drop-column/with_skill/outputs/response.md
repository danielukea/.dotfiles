# Safely Dropping the `legacy_notes` Column from `contacts`

## The core problem

Dropping a column is dangerous during a rolling deploy for one specific reason: **ActiveRecord caches the column list for each table at process startup.** When you run a migration that drops `legacy_notes`, any app process still running the *old* code expects that column to exist. The moment the column is gone, those processes raise `ActiveRecord::UnknownAttributeError` (or `PG::UndefinedColumn` on a `SELECT *`) until they're restarted with new code.

So the rule is: **don't drop the column until every running process has stopped referencing it.** This requires two separate deploys, not one.

There's also a sequencing subtlety even though you *think* the column is unused: a `remove_column` migration that runs before the new (column-ignoring) code is fully rolled out will still break the old processes. The two-deploy sequence below removes that risk regardless of whether code references it.

## Your specific situation: "not 100% sure it's unreferenced"

This is the important part. Do not drop the column based on a hunch. Before doing anything, verify it's actually unused. The two-deploy sequence below is also your safety net here — `ignored_columns` makes ActiveRecord behave as if the column doesn't exist, so if there *is* a stray reference you missed, you'll surface it in the first deploy (in staging/production with the new code) **before** the column is irreversibly dropped. That's much safer than discovering the reference after the data is gone.

### Step 0 — Verify it's unreferenced

Search the codebase thoroughly before trusting "it's not referenced":

```bash
# Ruby/ERB references
grep -rn "legacy_notes" app lib config db/seeds.rb

# Also check for indirect/string-based references that grep for the literal misses:
grep -rni "legacy_notes" app lib   # case-insensitive
```

Things to look for beyond direct `contact.legacy_notes` calls:
- `select`, `pluck`, `where`, raw SQL strings, or `order` clauses naming the column
- Serializers / JSON builders (`jbuilder`, `ActiveModel::Serializer`, API responses)
- Strong params permit lists (`params.permit(:legacy_notes)`)
- Form views / `form.text_area :legacy_notes`
- Reporting, exports, search indexing (e.g. Elasticsearch mappings)
- Database views, triggers, or foreign keys referencing the column
- Background jobs and any external consumers of the API

If you find references, remove them as part of Deploy 1 below.

## The safe 2-deploy sequence

### Deploy 1 — tell ActiveRecord to ignore the column, remove all code references

In the `Contact` model:

```ruby
class Contact < ApplicationRecord
  self.ignored_columns += ["legacy_notes"]
end
```

This makes ActiveRecord behave as if `legacy_notes` doesn't exist — it's excluded from `SELECT *`, from `attributes`, from the schema cache. Ship this (along with removal of any direct references you found in Step 0) and let it fully roll out so **every** running process is on the new code.

Why this comes first: once all processes ignore the column, dropping it can no longer crash anything.

### Deploy 2 — drop the column

After Deploy 1 is fully deployed and stable:

```ruby
class RemoveLegacyNotesFromContacts < ActiveRecord::Migration[7.2]
  def change
    safety_assured { remove_column :contacts, :legacy_notes }
  end
end
```

`remove_column` itself takes a brief `ACCESS EXCLUSIVE` lock, but for a plain column drop in Postgres this is a fast metadata-only operation (it doesn't rewrite the table), so it's safe.

Note on reversibility: `remove_column` without a type makes this migration irreversible — `rails db:rollback` will raise because Rails can't reconstruct the column. If you want a reversible `down` (which re-adds the empty column structure — the *data* is gone for good either way), specify the type: `remove_column :contacts, :legacy_notes, :text`.

After the migration has run in production, remove the `self.ignored_columns += ["legacy_notes"]` line from the model in a follow-up commit — it's served its purpose and is now dead config.

## About `safety_assured`

If the project uses the `strong_migrations` gem, a bare `remove_column` will be **blocked** at migration time with an error telling you AR caches columns and to use `ignored_columns` first. Once you've completed Deploy 1 (the column is ignored in all deployed code), wrapping the drop in `safety_assured { ... }` is the correct, intended use of the escape hatch — you've satisfied the precondition strong_migrations can't verify on its own. Don't reach for `safety_assured` to skip the `ignored_columns` step; only use it once the column is genuinely ignored everywhere.

If you have `strong_migrations` installed, it's also your deterministic gate: run `rails db:migrate` against a test DB in CI and it will fail the build on any unsafe migration before it reaches production.

## Summary checklist

1. [ ] Grep the codebase (and DB views/triggers/external consumers) for `legacy_notes`; remove any references found.
2. [ ] **Deploy 1:** Add `self.ignored_columns += ["legacy_notes"]` to `Contact` + ship the reference removals. Let it fully roll out.
3. [ ] **Deploy 2:** Run the `remove_column` migration (wrapped in `safety_assured` if `strong_migrations` is installed).
4. [ ] Follow-up: delete the now-unnecessary `ignored_columns` line.

The two deploys are what make this safe — never collapse them into one. The `ignored_columns` step doubles as your insurance against the references you "weren't 100% sure" about.
