# Mailers and Channels

## Mailers

A mailer is a thin presenter for one domain concept. Same rule as controllers: it selects data
and renders; it does not compute.

```ruby
class Notification::BundleMailer < ApplicationMailer
  def notification(bundle)
    @bundle = bundle
    mail to: bundle.user.email_address, subject: default_i18n_subject
  end
end
```

- **One mailer per domain concept**, not one per feature area. `ApplicationMailer` holds
  `default from:` and the layout.
- Pass the **record**, not a pile of primitives — the template can traverse it.
- Subjects belong in locale files (`default_i18n_subject`), not interpolated in Ruby.
- Any conditional about *whether* to send belongs on the model (`deliverable?`), not in the
  mailer.

### Deliver after commit, and deliver later

```ruby
after_create_commit :deliver_later
```

`deliver_now` inside a request makes the user wait on SMTP and makes the request fail when the
mail server is slow. `deliver_later` moves it to a job — which means it's subject to everything
in [`jobs.md`](jobs.md), including the enqueue-timing rule: from `after_create` on a
Redis-backed queue, the mail job can run before the row is committed.

`ActionMailer::MailDeliveryJob` is a job you don't own. To give it retry behavior, or the ambient
context a job needs, `prepend`/`include` into it from an initializer:

```ruby
ActiveSupport.on_load(:action_mailer) do
  ActionMailer::MailDeliveryJob.prepend AccountTenanted
end
```

### Distinguish permanent from transient delivery failures

Retrying a hard bounce forever is a bug; discarding a timeout loses mail. SMTP encodes the
difference in the response code, so dispatch on it:

```ruby
retry_on Net::OpenTimeout, Net::ReadTimeout, wait: :polynomially_longer
retry_on Net::SMTPServerBusy, wait: :polynomially_longer      # 452 insufficient storage

rescue_from Net::SMTPFatalError do |error|
  case error.message
  when /\A550 5\.1\.1/, /\A552 5\.6\.0/, /\A555 5\.5\.4/      # bad address — never retry
    Rails.error.report(error)
  else
    raise
  end
end
```

The `else raise` matters: an unrecognized fatal error should keep failing loudly rather than be
swallowed by a rescue that was only meant to catch known-permanent codes.

### Mailer URLs need a host

There is no request, so `default_url_options[:host]` must be configured per environment — and it
should point at a **canonical** host, not whatever tunnel or review-app URL a developer is on,
or emails will link somewhere unreachable.

```ruby
config.action_mailer.default_url_options = { host: "app.example.com" }
```

If the app is mounted under a path prefix, that prefix has to be passed explicitly too — nothing
infers it outside a request.

## Channels

```ruby
module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_user

    def connect
      self.current_user = find_verified_user || reject_unauthorized_connection
    end

    private
      def find_verified_user
        User.find_by(id: cookies.signed[:user_id])
      end
  end
end
```

**Authorize at connect and at subscribe — a channel is a trust boundary.** The stream name
arrives from the client, so a channel that streams whatever it's handed lets any connected user
subscribe to any record's updates:

```ruby
class CardChannel < ApplicationCable::Channel
  def subscribed
    card = current_user.accessible_cards.find_by(id: params[:id])
    card ? stream_for(card) : reject
  end
end
```

Note the same shape as a controller: the lookup starts from a **user-owned association**, so an
inaccessible record is never found rather than found-then-denied. See
[`controllers-and-routes.md`](controllers-and-routes.md).

Other things worth knowing:

- `stream_for(record)` over `stream_from("string")` — it derives a stable name from the record
  instead of a hand-built one that can drift.
- Broadcasts render **outside a request**, so anything derived from the request — the host, a
  path prefix, the current user — must be supplied explicitly.
- A connection is long-lived and holds a database connection while it works. Keep `subscribed`
  cheap; push real work to a job.
- `identified_by` enforces one connection per identifier, which is what lets you disconnect a
  user on sign-out.
