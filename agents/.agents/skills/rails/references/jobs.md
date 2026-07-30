# Jobs

## The shape: `_later` on the model, one line in the job

Real work belongs on the model. The job class is a thin trigger.

```ruby
module Notifiable
  extend ActiveSupport::Concern

  included do
    has_many :notifications, as: :source, dependent: :destroy
    after_create_commit :notify_recipients_later
  end

  def notify_recipients
    # the actual work
  end

  private
    def notify_recipients_later
      NotifyRecipientsJob.perform_later(self)
    end
end
```

```ruby
class NotifyRecipientsJob < ApplicationJob
  discard_on ActiveJob::DeserializationError

  def perform(record)
    record.notify_recipients
  end
end
```

Why this shape:

- The logic is **testable without the queue** — call `notify_recipients` directly.
- The enqueue point is **private**, so callers can't accidentally skip the callback contract.
- The job holds no branching, so retry semantics stay comprehensible.
- Renaming or reworking the work doesn't touch the job.

`_later` is the naming convention for "enqueues a job." Give the synchronous counterpart a
domain name (`deliver`, `reindex`, `notify_recipients`) rather than a mechanical `_now` suffix,
unless the pair genuinely needs to be symmetrical.

Jobs stay 3–10 lines. If a job grows conditionals, the model is missing a method.

## Enqueue timing depends on the backend

Whether `perform_later` inside a transaction is safe is **not** a job-design question — it
depends on where the queue stores the job. Full decision table, plus the version trap that
silently inverts on upgrade, in
[`transactions-and-callbacks.md`](transactions-and-callbacks.md).

Short version: a database-backed queue (Solid Queue) is inside your transaction and safe; a
Redis-backed one (Sidekiq) is not and races. Enqueuing from `after_*_commit` is correct under
both, which is why it's the default in the example above.

## Retries and discards

```ruby
class ApplicationJob < ActiveJob::Base
  # retry_on ActiveRecord::Deadlocked
  # discard_on ActiveJob::DeserializationError
end
```

Leaving these **commented out in the base class** is deliberate. `discard_on
ActiveJob::DeserializationError` means "if the record is gone, drop the job" — right for most
jobs, wrong for one that must alert on a missing record. Make it a per-job decision rather than
a blanket default nobody remembers making.

```ruby
retry_on Net::OpenTimeout, wait: :polynomially_longer
retry_on ReconcileAborted, wait: 1.minute, attempts: 3
discard_on ActiveJob::DeserializationError
```

Model "couldn't proceed, try later" as a **custom exception plus `retry_on`**, rather than
sleeping or re-enqueuing by hand. The model returns false; the job raises.

### Resolve records where `discard_on` can see the failure

A subtlety worth knowing if you deserialize anything yourself: raising
`ActiveJob::DeserializationError` during `deserialize` escapes the executor's rescue chain, so
`discard_on` never fires. Resolve in an `around_perform` instead, where the error lands inside
the execution path:

```ruby
# Account resolution is deferred to around_perform so a missing account raises
# DeserializationError inside the execution path, where discard_on can handle it.
around_perform :with_account_context
```

## Concurrency control

For a job that collapses state for one record, serialize on that record rather than guessing at
worker counts:

```ruby
class Storage::MaterializeJob < ApplicationJob
  queue_as :backend
  limits_concurrency to: 1, key: ->(owner) { owner }

  def perform(owner)
    owner.materialize_storage
  end
end
```

`limits_concurrency` (Solid Queue) keys on the argument itself, which makes fan-out safe: many
enqueues, one at a time per record.

## Long scans should be resumable

A deploy restarts workers. A job that has been running for ten minutes loses everything unless
it checkpoints. `ActiveJob::Continuable` (Rails **8.1**) makes resumption the default:

```ruby
class ReindexJob < ApplicationJob
  include ActiveJob::Continuable

  def perform
    step :reindex do |step|
      Card.find_each(start: step.cursor) do |card|
        card.reindex
        step.advance! from: card.id
      end
    end
  end
end
```

Before 8.1, do it manually — accept a cursor argument and re-enqueue yourself with the last id.

**In a batch job, a per-record failure must not abort the batch.** Report and continue:

```ruby
def safely_reindex(record)
  record.reindex
rescue StandardError => e
  Rails.error.report(e, context: { record_id: record.id })
end
```

Push pathological rows out **in SQL**, not in Ruby — a single oversized row can OOM the worker
during preload:

```ruby
.where("OCTET_LENGTH(body) <= ?", limit)
```

## Fan-out with one enqueue

`perform_all_later` writes the batch in one round trip instead of N:

```ruby
def deliver_all
  due.in_batches do |batch|
    ActiveJob.perform_all_later(batch.map { |b| DeliverJob.new(b) })
  end
end
```

## Recurring work

Keep the schedule declarative and the entry point trivial:

```yaml
# config/recurring.yml
deliver_bundled_notifications:
  command: "Notification::Bundle.deliver_all_later"
  schedule: every 30 minutes

auto_postpone_all_due:
  command: "Card.auto_postpone_all_due"
  schedule: every hour at minute 50

clear_finished_jobs:
  command: "SolidQueue::Job.clear_finished_in_batches(sleep_between_batches: 0.3)"
  schedule: every hour at minute 12
```

- **`command:` over `class:`** — a job class is only worth creating when there's real logic.
- Have the scheduled command call a `_later` method, so the scheduler's own execution stays
  instant and the real work goes through the queue.
- **Stagger the minutes** (`:50`, `:12`, `:25`) rather than defaulting everything to `:00`.
- The queue's own cleanup must be scheduled by you — the jobs table grows without bound
  otherwise.
- The file is ERB-evaluated, so entries can be environment-conditional.

## Carrying ambient context into a job

A job runs with no request, so anything a request would have established — the tenant, the
locale, the timezone — is absent. Capture it at enqueue time and restore it at perform time by
`prepend`ing a module that extends serialization:

```ruby
module AccountTenanted
  extend ActiveSupport::Concern

  prepended do
    attr_reader :account
    around_perform :with_account_context
  end

  def initialize(...)
    super
    @account = Current.account          # captured when enqueued
  end

  def serialize
    super.merge("account" => @account&.to_gid)
  end
end
```

`prepend`, not `include`, so `initialize`/`serialize` can call `super`. Framework jobs you don't
own — mail delivery, broadcasts — need the same treatment, applied from an initializer via
`ActiveSupport.on_load(:action_mailer)` or `config.after_initialize`. See
[`boot-and-autoloading.md`](boot-and-autoloading.md).

**Test that the job carries its own context** rather than inheriting it from the test process:

```ruby
def perform_enqueued_jobs(...)
  saved, Current.account = Current.account, nil   # jobs must not rely on ambient state
  super
ensure
  Current.account = saved
end
```

## Migrating Sidekiq jobs to Active Job

A codebase moving from `Sidekiq::Job` to Active Job has both conventions live at once. The
differences that cause bugs:

| Concern            | `Sidekiq::Job`                              | Active Job                                        |
| ------------------ | ------------------------------------------- | ------------------------------------------------- |
| Arguments          | JSON-native only — **pass ids**              | GlobalID — **pass the record**, Rails deserializes |
| Enqueue            | `perform_async`                             | `perform_later`                                   |
| Queue              | `sidekiq_options queue: :x`                 | `queue_as :x`                                     |
| Retries            | retries by default                          | **no retries** unless `retry_on` is declared       |
| Transaction safety | Redis is out-of-band — races                 | database-backed adapter is transactional           |

The retry difference is the quiet one: a Sidekiq job that relied on default retries becomes
fire-and-forget the moment it's converted, unless you add `retry_on` explicitly.

Passing a record to a Sidekiq job, or an id to an Active Job job, both "work" — one serializes
badly, the other loses the deserialization safety net. Match the convention of the base class
you're inheriting from.
