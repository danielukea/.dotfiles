# RubyLLM — Embeddings, Images, Audio & Moderation

Standalone helpers that mirror the chat surface. Sources:
[rubyllm.com/embeddings/](https://rubyllm.com/embeddings/),
[rubyllm.com/image-generation/](https://rubyllm.com/image-generation/),
[rubyllm.com/audio-transcription/](https://rubyllm.com/audio-transcription/),
[rubyllm.com/moderation/](https://rubyllm.com/moderation/).

## Embeddings — `RubyLLM.embed`

```ruby
RubyLLM.embed(text_or_texts, model: nil, dimensions: nil, provider: nil, assume_model_exists: false)
```

- `text_or_texts` — a `String` or an `Array<String>` (batch).
- `dimensions:` — custom output size (not all models support it).
- Config default: `config.default_embedding_model`.

```ruby
one   = RubyLLM.embed("Ruby is elegant and expressive")
one.vectors        # Array<Float>
one.model
one.input_tokens

many  = RubyLLM.embed(["Ruby", "Python", "JavaScript"])
many.vectors.length      # => 3  (array-of-arrays for batch input)
```

Common models: `text-embedding-3-small`, `text-embedding-3-large`,
`text-embedding-004`. Errors: `rescue RubyLLM::Error`.

## Image generation — `RubyLLM.paint`

```ruby
RubyLLM.paint(prompt, model:, size:, provider:, with:, mask:, params:, assume_model_exists:)
```

- `size:` — e.g. `"1024x1024"`, `"1792x1024"`, `"1024x1792"`.
- `with:` — source image(s) for **editing** (path, URL, IO, or ActiveStorage attachment).
- `mask:` — mask image constraining the editable region.
- `params:` — extra provider-specific hash.
- Config default: `config.default_image_model`.

```ruby
image = RubyLLM.paint("A photorealistic red panda coding Ruby on a laptop")
image.url            # OpenAI-style providers
image.data           # base64 (e.g. Google Imagen); image.base64? to check
image.mime_type
image.revised_prompt
image.model_id
image.tokens.input   # / .output
image.cost.total     # .input / .output
image.save("output.png")
image.to_blob
```

Editing with a mask:

```ruby
RubyLLM.paint(
  "Replace only the background with a sunset sky",
  model: "gpt-image-1",
  with:  "portrait.png",
  mask:  "portrait-mask.png",
  params: { size: "1024x1024" }
)
```

Errors: `RubyLLM::BadRequestError` for content-policy violations / bad args, otherwise
`RubyLLM::Error` (see [error-handling.md](error-handling.md)).

## Transcription — `RubyLLM.transcribe`

```ruby
RubyLLM.transcribe("meeting.wav")     # config.default_transcription_model
```

## Moderation — `RubyLLM.moderate`

```ruby
RubyLLM.moderate("Check if this text is safe")   # config.default_moderation_model
```

All four accept `assume_model_exists:` + `provider:` for unlisted models (see
[models.md](models.md)).
