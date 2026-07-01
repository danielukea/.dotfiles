# Safely Dropping the `legacy_notes` Column

## The core problem

ActiveRecord caches the table's schema (column list) at boot. When you drop a column, any running process that still holds the old cached schema will keep referencing the dropped column in its queries. Those queries blow up with `PG::UndefinedColumn`. This happens during the window between when the migration runs and when every app process has restarted/redeployed.

## The safe sequence (two deploys)

### Deploy 1 — ignore the column in the model

```ruby
class Contact < ApplicationRecord
  self.ignored_columns += ["legacy_notes"]
end
```

Deploy this and let it fully roll out. Now ActiveRecord builds its queries as if the column doesn't exist — it stops selecting `legacy_notes`. After this is fully deployed, no running code references the column at the database level.

### Deploy 2 — drop the column

```ruby
class RemoveLegacyNotesFromContacts < ActiveRecord::Migration[7.1]
  def change
    remove_column :contacts, :legacy_notes, :text
  end
end
```

Always specify the column type (`:text` here) in `remove_column` — this makes the migration reversible.

### Cleanup

Once the drop is deployed and stable, remove the `ignored_columns` line in a subsequent change.

## Before any of that: confirm it's actually unused

Since you're "not 100% sure," verify first:

1. **Grep the codebase** for every form of the name:
   ```
   grep -rni "legacy_notes" app lib config db/schema.rb
   ```
   Check for direct references, serializers/JSON builders, `permit(:legacy_notes)` in strong params, search allowlists, CSV exports, and reporting queries.

2. **Check outside the Rails app** — other services reading the same database, ETL pipelines, data warehouse syncs, BI tools (Looker, Tableau), background reporting jobs.

3. **Confirm there's no data you need to keep.** Dropping the column destroys the data:
   ```sql
   SELECT count(*) FROM contacts WHERE legacy_notes IS NOT NULL;
   ```

4. **Check for dependent objects** at the DB level: indexes, views, triggers that reference `legacy_notes` — those must be dropped first.

## Summary

- [ ] Grep app + external consumers for `legacy_notes`
- [ ] Confirm data isn't needed
- [ ] Check for indexes/views/triggers on the column
- [ ] **Deploy 1:** `self.ignored_columns += ["legacy_notes"]`, roll out fully
- [ ] **Deploy 2:** `remove_column :contacts, :legacy_notes, :text`
- [ ] **Cleanup:** remove the `ignored_columns` line
