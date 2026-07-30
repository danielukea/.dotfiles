# Style — how Rails code reads

Code is read far more often than written. These conventions optimize for reading.

## Prefer expanded conditionals over guard clauses

This is the opposite of most style guides, and the opposite of what most generated code does.

```ruby
# ❌
def todos_for_new_group
  ids = params.require(:todolist)[:todo_ids]
  return [] unless ids
  @bucket.recordings.todos.find(ids.split(","))
end

# ✅
def todos_for_new_group
  if ids = params.require(:todolist)[:todo_ids]
    @bucket.recordings.todos.find(ids.split(","))
  else
    []
  end
end
```

The expanded form shows both outcomes in one shape. Guard clauses get hard to follow as soon as
they nest, and they scatter a method's exits.

Two cases where a guard clause is right:

- the return is at the **very beginning** of the method
- the main body is non-trivial — several lines — so an early exit genuinely reduces nesting

```ruby
def after_recorded_as_commit(recording)
  return if recording.parent.was_created?

  if recording.was_created?
    broadcast_new_column(recording)
  else
    broadcast_column_change(recording)
  end
end
```

## Method ordering

1. class methods
2. public methods, with `initialize` first
3. private methods

Then order **vertically by invocation** — a method appears immediately below its first caller,
depth-first. Reading top to bottom follows the flow of execution:

```ruby
class SomeClass
  def some_method
    method_1
    method_2
  end

  private
    def method_1
      method_1_1
      method_1_2
    end

    def method_1_1
    end

    def method_1_2
    end

    def method_2
    end
end
```

## Visibility modifiers

No blank line under `private`, and indent everything beneath it. The indentation is what makes
the section visible when scanning:

```ruby
class SomeClass
  def some_method
  end

  private
    def some_private_method
    end
end
```

Exception: a module that is *entirely* private methods marks `private` at the top, adds a blank
line, and does **not** indent.

```ruby
module SomeModule
  private

  def some_private_method
  end
end
```

## To bang or not to bang

Use `!` **only** when a non-bang counterpart exists — `save`/`save!`, `update`/`update!`.

`!` does not mean "destructive." Ruby and Rails are full of destructive methods without it
(`destroy`, `delete`, `clear`, `pop`). A lone `gild!` with no `gild` misleads the reader into
looking for the safe version.

```ruby
def close   # ✅ there is no `close?`-style safe variant to distinguish from
def close!  # ❌ nothing to contrast with
```

## Model web endpoints as CRUD on resources

When an action doesn't map to a CRUD verb, introduce a resource — don't add a custom action:

```ruby
# ❌
resources :cards do
  post :close
  post :reopen
end

# ✅
resources :cards do
  resource :closure
end
```

Full treatment, with worked controllers → [`controllers-and-routes.md`](controllers-and-routes.md).

## Controllers call the model directly

Plain Active Record in a controller is fine:

```ruby
class Cards::CommentsController < ApplicationController
  def create
    @comment = @card.comments.create!(comment_params)
  end
end
```

For anything more involved, give the model an intention-revealing method and call that:

```ruby
class Cards::GoldnessesController < ApplicationController
  def create
    @card.gild
  end
end
```

No intermediate layer connects the two. When a plain object genuinely helps — a multi-step
signup, a complex calculation — write one, but treat it as an ordinary class rather than a
required architectural artifact:

```ruby
Signup.new(email_address: email_address).create_identity
```

## Run async work in jobs, keep the job shallow

Suffix `_later` for the method that enqueues, and give the synchronous counterpart a domain
name. The job itself is one line — see [`jobs.md`](jobs.md).

## Anti-patterns

When you feel the pull toward the left column, reach for the right instead.

| Instead of                            | Because                                                                       | Do this                                                            |
| ------------------------------------- | ----------------------------------------------------------------------------- | ------------------------------------------------------------------ |
| a service object by default            | hides domain logic from the model that owns the data; creates a parallel API   | a model method named for the intent                                |
| a custom controller action (`post :close`) | mixes mutation verbs into a resource controller; doesn't scale             | a new resource                                                     |
| `enum` + a state machine for status    | single-axis state; no who/when; hard to combine with other states             | a real `has_one` state record                                      |
| a fat job class                        | untestable, and the logic is split between job and model                      | `_later` enqueues; `perform` delegates back to the model            |
| `default_scope` for tenancy            | surprises you in the console, joins, and raw SQL; hard to undo                | scope through a user-owned association at the query's entry point   |
| a callback for a state transition      | invisible and easy to trigger accidentally                                    | an explicit method; callbacks for passive effects only              |
| a form object to validate a combination | splits validation between the form and the model                             | validations on the model                                           |
| a policy object layer                  | adds a layer for what query scoping already enforces                          | scope the query; add explicit `ensure_*` predicates                |
| guard clauses everywhere               | hard to read once nested                                                      | expanded conditionals; guards only as described above              |
| `!` to mark "destructive"              | misleading — `!` means "has a non-bang counterpart"                           | drop the `!`                                                       |
| a presenter/decorator layer by default | another indirection for what a helper or partial already does                  | a helper, a partial, or `to_partial_path`                          |
| no `scope :preloaded` on a list model  | every partial fires a query per row                                           | define it and pipe list queries through it                         |

Each of these is a default, not a prohibition. A codebase with an established local pattern
wins — see `## Precedence` in [`SKILL.md`](../SKILL.md).
