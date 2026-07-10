# The Rails Migration Generator & API

How to create migrations with `rails generate migration` and the migration DSL. Read this when you
need the exact generator name-parsing rules or the schema-statement API. For making a migration
*deploy-safe*, see `safe-sequences.md`.

## Contents

- [Generating a migration](#generating-a-migration)
- [Name-parsing conventions](#name-parsing-conventions)
- [Field type modifiers](#field-type-modifiers)
- [The migration API](#the-migration-api)
- [Reversibility](#reversibility)
- [Non-transactional migrations](#non-transactional-migrations)
- [Schema file & version tracking](#schema-file--version-tracking)

## Generating a migration

```bash
bin/rails generate migration <MigrationName> [field:type[:index] ...]
```

Rails prepends a UTC timestamp, producing `db/migrate/YYYYMMDDHHMMSS_migration_name.rb`, and — when the
name matches a known pattern — fills in the migration body from the name and the field list. A name
that matches nothing valid generates an empty `change` method for you to fill in.

## Name-parsing conventions

| Name pattern | Example | Generated body |
|---|---|---|
| `CreateX` | `CreateProducts name:string part_number:string` | `create_table :products` with those columns + `t.timestamps` |
| `AddXToY` / `AddColumnsToY` | `AddPartNumberToProducts part_number:string` | `add_column :products, :part_number, :string` |
| `RemoveXFromY` | `RemovePartNumberFromProducts part_number:string` | `remove_column :products, :part_number, :string` |
| `Add<Ref>RefToY` | `AddUserRefToProducts user:references` | `add_reference :products, :user, null: false, foreign_key: true` |
| field `:index` suffix | `AddPartNumberToProducts part_number:string:index` | `add_column` **and** `add_index` |
| `CreateJoinTableXY` | `CreateJoinTableUserProduct user product` | `create_join_table :users, :products` |

The `AddXToY`/`RemoveXFromY` table inference and column generation only fire when the name ends in
`ToTable` / `FromTable`; otherwise you get an empty migration.

> Note: `add_reference` in one step builds a **non-concurrent** index and a **validated** FK — both
> block writes on a large table, and some projects ban it. For a live table, prefer generating a plain
> column and adding the index/FK in separate migrations (see `safe-sequences.md` → Adding an Index /
> Adding a Foreign Key).

## Field type modifiers

Passed on the command line as part of each `field:type`:

- `field:string!` → `null: false`
- `'price:decimal{5,2}'` → `add_column ..., :decimal, precision: 5, scale: 2` (quote it against the shell)
- `supplier:references{polymorphic}` → polymorphic reference
- `field:string:uniq` → unique index; `field:string:index` → plain index

Common types: `string`, `text`, `integer`, `bigint`, `float`, `decimal`, `datetime`, `timestamp`,
`time`, `date`, `boolean`, `binary`, `json`, `jsonb`, `uuid`, `references`.

## The migration API

**`change` (default, auto-reversible for most operations):**
```ruby
class CreateProducts < ActiveRecord::Migration[8.0]
  def change
    create_table :products do |t|
      t.string :name
      t.timestamps
    end
  end
end
```
Reversible inside `change`: `create_table`, `create_join_table`, `add_column`, `add_index`,
`add_reference`, `add_foreign_key`, `rename_column`, `rename_table`, `change_column_null`,
`change_column_default` (with `:from`/`:to`), `remove_column` (with type/options), `drop_table` (with a
block that recreates it).

**`up`/`down` (explicit control)** — use when an operation isn't auto-reversible:
```ruby
def up
  execute "ALTER TYPE ..."
end

def down
  execute "ALTER TYPE ..."
end
```

**Column / index / constraint statements:**
`add_column`, `remove_column`, `change_column` (irreversible — use `up`/`down` or `reversible`),
`change_column_null`, `change_column_default`, `rename_column`; `add_index`, `remove_index`;
`add_reference`; `add_foreign_key`, `validate_foreign_key`, `remove_foreign_key`;
`add_check_constraint`, `validate_check_constraint`, `remove_check_constraint`. `change_table` batches
several against one table.

## Reversibility

- `change_column` and raw `execute` are not auto-reversible — provide `up`/`down`, or wrap in
  `reversible { |dir| dir.up { ... }; dir.down { ... } }`.
- `remove_column` needs the original type (and relevant options) to be reversible.
- If an operation genuinely can't be undone, raise in `down`:
  ```ruby
  def down
    raise ActiveRecord::IrreversibleMigration, "destroys data"
  end
  ```
- Don't edit a committed migration — write a new one. Use `revert` to undo a prior migration's effect.

## Non-transactional migrations

`disable_ddl_transaction!` runs the migration outside a transaction. Required for:
- Concurrent index builds — `add_index ..., algorithm: :concurrently` (Postgres can't build
  `CONCURRENTLY` inside a transaction).
- Batched backfills that shouldn't hold one long transaction.

Because there's no transaction, such a migration **must contain exactly one statement** — a later
failure can't roll back an earlier committed one. See `safe-sequences.md` → Backfilling Data.

## Schema file & version tracking

Rails records applied migrations in the `schema_migrations` table (a `version` per migration) and dumps
the schema after `db:migrate`:
- **`schema.rb`** — Ruby DSL, the default (`config.active_record.schema_format = :ruby`). Can't express
  triggers, functions, or other DB-specific objects.
- **`structure.sql`** — raw SQL dump (`:sql`), accurate for complex schemas (partial indexes, extensions,
  check constraints). Generated via `pg_dump`.

Which format a project uses is a per-project setting — check `config/application.rb`. Load a fresh DB
from the dumped schema with `bin/rails db:schema:load` (faster than replaying every migration). Only
commit a schema-file change when your branch actually adds or edits a migration.
