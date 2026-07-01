---
name: sprout-sync
description: User-invoked skill (/sprout-sync) — syncs the local dev database and sprout seed with origin/master. Restores db/structure.sql, pulls latest, removes stray migrations from other worktrees, runs pending migrations, and re-exports the sprout. Only invoke when the user explicitly runs /sprout-sync.
---

# sprout-sync

Brings the local dev database (and its `db/structure.sql` snapshot) into perfect alignment with `origin/master`, then re-exports the sprout. This preserves all existing dev data — it does **not** reset the database.

The most common source of drift: a worktree on a feature branch runs migrations locally, which writes into the shared dev database and leaves stray `schema_migrations` records even after you switch back to master.

---

## Steps

Work through these in order. After each step, confirm success before proceeding. Stop and surface any errors rather than pushing through.

### 1. Restore `db/structure.sql`

Check whether the file has drifted from `origin/master`:

```bash
git fetch origin master --quiet
git diff --stat origin/master -- db/structure.sql
```

If there's a diff, restore it:

```bash
git checkout origin/master -- db/structure.sql
```

If you have uncommitted changes in the working tree (other than `db/structure.sql`), stash them before pulling:

```bash
git stash
```

### 2. Pull latest from `origin/master`

```bash
git pull origin master
```

This gets the migration files for any commits that landed on master since your last pull. If the pull fast-forwards cleanly, proceed. If there are conflicts, surface them and stop — don't try to resolve them silently.

Pop the stash afterward if you stashed in step 1:

```bash
git stash pop
```

### 3. Identify stray migrations

A stray migration is a `schema_migrations` record in the local db that doesn't appear in `origin/master`'s `db/structure.sql`. These typically come from feature branches run in another worktree.

Extract which versions are on master:

```bash
grep -oP "\('\K[0-9]{14}(?='\))" db/structure.sql | sort > /tmp/master_versions.txt
```

Query the live db for all versions:

```bash
bin/wealthbox psql "SELECT version FROM schema_migrations ORDER BY version;" \
  | tail -n +3 | grep -v "^$" | grep -v "rows)" | awk '{print $1}' | sort > /tmp/db_versions.txt
```

Find the strays:

```bash
comm -23 /tmp/db_versions.txt /tmp/master_versions.txt
```

If the output is empty, there are no stray migrations — skip to step 5.

### 4. Remove stray migrations

For each stray version, you need to:

1. **Find what tables it created** — compare db tables against master's structure:

```bash
grep -oP 'CREATE TABLE public\.\K[a-z_]+' db/structure.sql | sort > /tmp/master_tables.txt

bin/wealthbox psql "SELECT table_name FROM information_schema.tables WHERE table_schema = 'public' AND table_type = 'BASE TABLE' ORDER BY table_name;" \
  | tail -n +3 | grep -v "^$" | grep -v "rows)" | awk '{print $1}' | sort > /tmp/db_tables.txt

comm -23 /tmp/db_tables.txt /tmp/master_tables.txt
```

   Partitioned child tables (`_p0`, `_p1`, …) and `console1984_*` tables are expected to be "extra" — they're created at runtime, not by stray migrations. Ignore them. Focus on any other tables that appear unexpectedly.

2. **Show the user what will be dropped** — list the tables and ask for confirmation before proceeding.

3. **Drop the tables and remove the migration record** in a single psql call:

```bash
bin/wealthbox psql "DROP TABLE <table_name>; DELETE FROM schema_migrations WHERE version = '<version>';"
```

   If you're unsure which tables belong to a specific stray migration, inspect the table structure (`\d <table_name>`) for clues — column names and foreign keys usually reveal the feature it came from.

### 5. Run pending migrations

```bash
bin/wealthbox exec bundle exec rails db:migrate
```

Watch the output. Each migration should print `migrated (Xs)`. If any error out, stop and surface the failure — don't proceed to the sprout export with a partial migration run.

### 6. Verify clean state

Confirm there are no outstanding `down` migrations:

```bash
bin/wealthbox exec bundle exec rails db:migrate:status 2>&1 | grep "^ *down"
```

If this returns nothing, the db is fully migrated and matches master.

### 7. Export the sprout

**Warn the user first**: this will overwrite the existing sprout at `~/.wb/seeds/crm-web/sprout.dump`. Get explicit confirmation before running.

```bash
bin/wealthbox seed export sprout
```

Confirm the export completed successfully and report the file size from the output.

---

## Constraints

- **Never** run `rails db:seed` — it truncates all tables and destroys dev data.
- **Always** use `bin/wealthbox psql` for database queries, not `psql` directly.
- **Always** use `bin/wealthbox exec bundle exec rails` for Rails commands.
- **Always** use `bin/wealthbox rspec` for tests — not `bin/wealthbox exec bundle exec rspec`.
- The sprout export is **destructive to the sprout file** — always confirm before overwriting.
- Dropping tables is **destructive to db data** — always confirm with the user before dropping.
