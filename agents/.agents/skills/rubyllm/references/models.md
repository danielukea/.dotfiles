# RubyLLM — Model Registry

Sources: [rubyllm.com/models/](https://rubyllm.com/models/) ("Model Registry", the
guide) and [rubyllm.com/available-models/](https://rubyllm.com/available-models/) (a
generated browse table of all registered models; raw JSON at
[rubyllm.com/models.json](https://rubyllm.com/models.json)).

## Selecting a model / provider

The provider is inferred from the model id; override it explicitly when ambiguous or
for a custom endpoint:

```ruby
RubyLLM.chat                                              # config.default_model
RubyLLM.chat(model: "gpt-5-nano")                        # provider inferred (OpenAI)
RubyLLM.chat(model: "claude-sonnet-4-6", provider: :anthropic)
RubyLLM.chat(model: "llama-3", provider: :ollama)
```

## The registry API

```ruby
RubyLLM.models.all
RubyLLM.models.chat_models
RubyLLM.models.embedding_models
RubyLLM.models.by_provider(:openai)                      # or "openai"
RubyLLM.models.by_family("claude3_sonnet")
RubyLLM.models.by_provider(:openai).select(&:supports_vision?)

info = RubyLLM.models.find("gpt-5.4")                    # RubyLLM::Model::Info
info = RubyLLM.models.find("claude-sonnet-4-6", :anthropic)  # disambiguate by provider
```

`find` **raises `RubyLLM::ModelNotFoundError`** for an unknown id — it does not return
`nil` (see [gotchas.md](gotchas.md)). Aliases are defined in the gem's
`lib/ruby_llm/aliases.json`; `chat.model.id` shows the resolved concrete id.

`Model::Info` fields: `id`, `provider`, `type` (`chat`/`embedding`/…), `name`,
`context_window`, `max_tokens`, `supports_vision`, `supports_functions`,
`input_price_per_million`, `output_price_per_million`,
`cache_read_input_price_per_million` / `cache_write_input_price_per_million` (v1.15+),
`family`.

## Refreshing & persisting

```ruby
RubyLLM.models.refresh!                       # in-memory only; queries provider APIs + models.dev
RubyLLM.models.refresh!(remote_only: true)    # skip local providers
RubyLLM.models.refresh!.chat_models           # chainable
RubyLLM.models.save_to_json                   # persist to config.model_registry_file
RubyLLM.models.save_to_json("/var/app/models.json")
```

`refresh!` is in-memory only — persist with `save_to_json` + `config.model_registry_file`
(needed for read-only gem dirs; see [getting-started.md](getting-started.md)). In Rails
with the DB-backed registry, use `Model.refresh!` / `bin/rails ruby_llm:load_models`
(see [rails.md](rails.md)).

## Cost

```ruby
model = RubyLLM.models.find("gpt-5-nano")
response = RubyLLM.chat(model: model.id, provider: model.provider).ask("…")
cost = model.cost_for(response.tokens)        # .input / .output / .cache_read / .cache_write / .thinking / .total
RubyLLM::Cost.aggregate(messages.map(&:cost)).total
```

## Unlisted / custom models

To use a model not in the registry (private deployment, brand-new release), name the
provider and assume existence — this bypasses registry validation and capability checks
(logs a warning):

```ruby
RubyLLM.chat(model: "my-secure-gpt", provider: :openai, assume_model_exists: true)
chat.with_model("gpt-5-alpha", provider: :openai, assume_exists: true)   # NOTE: assume_exists:, not assume_model_exists:
RubyLLM.embed("text", model: "my-embedder", provider: :openai, assume_model_exists: true)
RubyLLM.paint("prompt", model: "my-dalle",  provider: :openai, assume_model_exists: true)
```

`provider:` is mandatory when assuming existence. The kwarg-name asymmetry between the
top-level methods (`assume_model_exists:`) and `Chat#with_model` (`assume_exists:`) is a
documented footgun — see [gotchas.md](gotchas.md).

**Default model names churn** — set `config.default_model` and verify ids against the
live registry rather than hardcoding from memory.
