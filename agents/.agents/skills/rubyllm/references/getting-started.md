# RubyLLM — Getting Started & Configuration

Sources: [rubyllm.com/getting-started/](https://rubyllm.com/getting-started/),
[rubyllm.com/configuration/](https://rubyllm.com/configuration/),
[rubyllm.com/overview/](https://rubyllm.com/overview/). There is **no** standalone
`/installation` page — that URL redirects into Getting Started.

## Install

```ruby
# Gemfile
gem "ruby_llm"          # then: bundle install
# or:  bundle add ruby_llm
```

Minimal setup, then first call:

```ruby
require "ruby_llm"

RubyLLM.configure do |config|
  config.openai_api_key    = ENV.fetch("OPENAI_API_KEY", nil)
  # config.anthropic_api_key = ENV.fetch("ANTHROPIC_API_KEY", nil)
end

puts RubyLLM.chat.ask("What is Ruby on Rails?").content
```

In Rails, put the `configure` block in `config/initializers/ruby_llm.rb` (the
`ruby_llm:install` generator creates it — see [rails.md](rails.md)).

## The three configuration tiers

1. **Global** — `RubyLLM.configure { |c| … }`, process-wide defaults.
2. **Context** — `RubyLLM.context { |c| … }`, an isolated, thread-safe copy for one
   scope (e.g. a tenant). Does not mutate global config.
3. **Instance** — kwargs on `RubyLLM.chat(model:, temperature:, …)`.

```ruby
context = RubyLLM.context do |config|
  config.openai_api_key   = tenant.api_key
  config.request_timeout  = 180
end
chat = context.chat(model: "gpt-5.4")   # uses the isolated config
```

## Provider API keys

All under `RubyLLM.configure do |config| … end`. Supported providers and their keys
(base-URL overrides shown where they exist):

- **OpenAI** — `openai_api_key`, `openai_api_base`, `openai_organization_id`,
  `openai_project_id`, `openai_use_system_role` (Boolean — send `system` instead of the
  default `developer` role, for OpenAI-compatible servers).
- **Anthropic** — `anthropic_api_key`, `anthropic_api_base`.
- **Gemini** — `gemini_api_key`, `gemini_api_base` (e.g.
  `https://generativelanguage.googleapis.com/v1` to force stable v1 over v1beta).
- **Vertex AI** — `vertexai_project_id`, `vertexai_location`,
  `vertexai_service_account_key` (optional; falls back to Application Default
  Credentials), `vertexai_api_base`.
- **Bedrock** — `bedrock_api_key`, `bedrock_secret_key`, `bedrock_region` (required),
  `bedrock_session_token`, `bedrock_api_base`.
- **Azure (OpenAI)** — `azure_api_base`, `azure_api_key`, `azure_ai_auth_token`.
- **DeepSeek** — `deepseek_api_key`, `deepseek_api_base`.
- **Mistral** — `mistral_api_key`, `mistral_api_base`.
- **OpenRouter** — `openrouter_api_key`, `openrouter_api_base`.
- **Perplexity** — `perplexity_api_key`, `perplexity_api_base`.
- **xAI** — `xai_api_key`, `xai_api_base`.
- **Ollama** (local) — `ollama_api_base` (e.g. `http://localhost:11434/v1`),
  `ollama_api_key`.
- **GPUStack** (local) — `gpustack_api_base`, `gpustack_api_key`.

Using a provider whose key isn't set raises `RubyLLM::ConfigurationError`.

## Default models

```ruby
config.default_model              = "claude-sonnet-4-6"        # RubyLLM.chat
config.default_embedding_model    = "text-embedding-3-large"   # RubyLLM.embed
config.default_image_model        = "dall-e-3"                 # RubyLLM.paint
config.default_moderation_model   = "..."                      # RubyLLM.moderate
config.default_transcription_model = "..."                     # RubyLLM.transcribe
```

Built-in fallbacks if unset (as documented — **verify against the current gem**, these
names churn): chat `gpt-5-nano`, embeddings `text-embedding-3-small`, images
`gpt-image-1.5`.

## Connection, retries, logging

```ruby
config.request_timeout          = 120     # seconds (default 300)
config.max_retries              = 3       # default 3
config.retry_interval           = 0.1     # default 0.1
config.retry_backoff_factor     = 2       # default 2
config.retry_interval_randomness = 0.5    # default 0.5
config.http_proxy               = "http://user:pass@proxy:8080"  # also socks5://
config.faraday_adapter          = :net_http   # default

config.log_file  = "/var/log/ruby_llm.log"
config.log_level = :info                  # :debug | :info | :warn
config.logger    = Rails.logger           # overrides log_file/log_level
config.log_stream_debug = true            # verbose per-chunk stream debug (or RUBYLLM_STREAM_DEBUG=true)
```

Retries are automatic for rate-limit / timeout / server errors (see
[error-handling.md](error-handling.md)). `RUBYLLM_DEBUG=true` env var enables
request/response debug logging.

## Custom / OpenAI-compatible endpoints

Point the OpenAI base URL at any compatible server (Azure, a local gateway, a
self-hosted model) and bypass registry validation:

```ruby
RubyLLM.configure do |config|
  config.openai_api_key = ENV["CUSTOM_API_KEY"]
  config.openai_api_base = "https://YOUR_AZURE_RESOURCE.openai.azure.com"  # or http://localhost:8080/v1
end

chat = RubyLLM.chat(model: "my-custom-model", provider: :openai, assume_model_exists: true)
```

`provider:` is **required** when `assume_model_exists: true`. See
[models.md](models.md) for the full registry / custom-model story.

## Rails-specific config keys

`config.use_new_acts_as` (registry-based `acts_as`, default `true` since 1.7),
`config.model_registry_class` (custom `Model` class name), `config.instrumenter`,
`config.deprecation_behavior` (`:warn`/`:silence`/`:raise`). See [rails.md](rails.md);
note the `use_new_acts_as` placement gotcha in [gotchas.md](gotchas.md).
