# RubyLLM — Agents, Workflows & Async

Sources: [rubyllm.com/agents/](https://rubyllm.com/agents/),
[rubyllm.com/agentic-workflows/](https://rubyllm.com/agentic-workflows/),
[rubyllm.com/async/](https://rubyllm.com/async/).

## Agents — package a reusable configuration

`RubyLLM::Agent` bundles a model, instructions, tools, and params into a named class:

```ruby
class WorkAssistant < RubyLLM::Agent
  model "gpt-5-nano"
  instructions "You are a helpful assistant."   # or a block, or an ERB template (see below)
  tools SearchDocs, LookupAccount
  temperature 0.2
  params max_output_tokens: 256
  chat_model                                     # opt into Rails/AR persistence mode
end
```

Three ways to use it:

```ruby
chat = WorkAssistant.chat; chat.ask("Hello")     # plain Ruby, returns a Chat
agent = WorkAssistant.new; agent.ask("Hello")    # instance API; agent.cost.total
chat = WorkAssistant.create!(user: current_user) # Rails mode (requires `chat_model`)
same = WorkAssistant.find(chat.id)
```

The Rails generator `bin/rails g ruby_llm:agent Support` scaffolds
`app/agents/support_agent.rb` plus a default instructions template at
`app/prompts/support_agent/instructions.txt.erb` (see [rails.md](rails.md)).

## Agentic workflows

The [/agentic-workflows/](https://rubyllm.com/agentic-workflows/) guide treats
orchestration as **plain Ruby**, not a framework construct — sequential chaining,
routing, parallel fan-out/fan-in (via `Async`), and evaluation loops, composing the
`chat`/`agent`/`embed` primitives directly. RAG is covered as: embed with
`RubyLLM.embed` (see [embeddings-images-media.md](embeddings-images-media.md)), store
vectors in pgvector via the Neighbor gem, retrieve, then feed context into a chat.

## Async — non-blocking by context

RubyLLM becomes non-blocking **automatically inside an `Async` context** — no config
flag:

```ruby
require "async"
require "ruby_llm"

Async do
  10.times.map do
    Async { puts RubyLLM.chat.ask("Explain quantum computing").content }
  end.map(&:wait)
end
```

- Rate-limit concurrent fan-out with `Async::Semaphore`.
- Recommended app server: **Falcon** (fiber-native). Puma needs
  `async-job-processor-redis`; Rails: `config.active_job.queue_adapter = :async_job`.
- `Async::Job` background jobs work unmodified.
- **Rails caveat:** for fiber-heavy workloads (e.g. streaming) also set
  `config.active_support.isolation_level = :fiber` in `config/application.rb` (Rails
  7.2.1+/8.x). This appears on the Rails page, not the Async page — see
  [gotchas.md](gotchas.md).

## Ecosystem (companion gems)

From [rubyllm.com/ecosystem/](https://rubyllm.com/ecosystem/): `ruby_llm-schema`
(structured-output DSL, a core dep), `ruby_llm-mcp` (MCP client),
`ruby_llm-instrumentation` / `ruby_llm-monitoring` (Rails observability),
`ruby_llm-red_candle` (local GGUF inference), `opentelemetry-instrumentation-ruby_llm`,
`ruby_llm-tribunal` (LLM evals), `ruby_llm-top_secret` (PII filtering), `ruby_llm-test`
(RSpec/Minitest stubbing).
