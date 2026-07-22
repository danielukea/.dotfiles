# RubyLLM — Error Handling

Source: [rubyllm.com/error-handling/](https://rubyllm.com/error-handling/).

## Exception hierarchy

**API errors** (subclass `RubyLLM::Error`, carry the failed HTTP response):

| Class | Condition |
| --- | --- |
| `RubyLLM::BadRequestError` | 400 (bad args, content-policy) |
| `RubyLLM::UnauthorizedError` | 401 (bad/missing key) |
| `RubyLLM::PaymentRequiredError` | 402 |
| `RubyLLM::ForbiddenError` | 403 |
| `RubyLLM::ContextLengthExceededError` | context window exceeded |
| `RubyLLM::RateLimitError` | 429 |
| `RubyLLM::ServerError` | 500 |
| `RubyLLM::ServiceUnavailableError` | 502/503/504 |
| `RubyLLM::OverloadedError` | 529 |

**Non-API errors** (subclass `StandardError`, not `RubyLLM::Error`):
`RubyLLM::ConfigurationError`, `RubyLLM::ModelNotFoundError`,
`RubyLLM::InvalidRoleError`.

## Catching

```ruby
begin
  RubyLLM.chat.ask("Your prompt")
rescue RubyLLM::UnauthorizedError
  # auth failure — bad/missing key
rescue RubyLLM::RateLimitError
  # backoff / queue
rescue RubyLLM::Error => e
  # any remaining API error
  e.response      # the underlying Faraday::Response, for provider-specific debugging
end
```

Rescuing `RubyLLM::Error` does **not** catch `ConfigurationError` /
`ModelNotFoundError` / `InvalidRoleError` (they descend from `StandardError`). During
streaming, provider errors surface after the block finishes (see
[streaming.md](streaming.md)).

## Built-in retries

RubyLLM automatically retries rate-limit / timeout / server errors before raising.
Tune in `RubyLLM.configure` (see [getting-started.md](getting-started.md)):

```ruby
config.max_retries              = 5     # default 3
config.retry_interval           = 0.5   # default 0.1
config.retry_backoff_factor     = 2     # default 2
config.retry_interval_randomness = 0.5  # default 0.5
```

Debug requests/responses with `RUBYLLM_DEBUG=true`.
