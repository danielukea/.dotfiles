# RubyLLM — Chat

Source: [rubyllm.com/chat/](https://rubyllm.com/chat/) ("Chatting with AI Models").
The structured-output section of this page is documented in
[tools-and-schemas.md](tools-and-schemas.md).

## Create and ask

```ruby
chat = RubyLLM.chat                              # default model from config
chat = RubyLLM.chat(model: "claude-sonnet-4-6")  # by id or alias
chat = RubyLLM.chat(model: "gpt-5-nano", temperature: 0.2)  # kwargs allowed here

response = chat.ask("Explain 'Convention over Configuration' in Rails.")  # => RubyLLM::Message
response.content
response.model_id
response.tokens.input   # and .output
```

`chat.say` is a documented alias for `ask`. `ask` sends a `:user` message plus the full
history and returns a `RubyLLM::Message`.

## History

```ruby
chat.messages                       # Array<RubyLLM::Message>, roles :user/:assistant/:system/:tool
chat.messages.each { |m| puts "[#{m.role}] #{m.content}" }
chat.add_message(role: :system, content: "System instruction")
chat.add_message(role: :user, content: "User message")
```

## Chainable modifiers (each returns `self`)

```ruby
chat
  .with_instructions("You are a Ruby expert.")          # system prompt (replaces)
  .with_instructions("Be concise.", append: true)        # add without replacing
  .with_model("claude-sonnet-4-6")                       # switch mid-conversation
  .with_temperature(0.9)                                 # 0.2 factual … 0.9 creative
  .with_params(response_format: { type: "json_object" }) # raw request-payload override
  .with_headers("anthropic-beta" => "fine-grained-tool-streaming-2025-05-14")
  .with_tool(Weather)                                    # see tools-and-schemas.md
  .with_schema(PersonSchema)                             # see tools-and-schemas.md
```

- `with_params` merges into / overrides the raw request body — powerful and unsafe;
  it can clobber `model`, `max_tokens`, `tools`, etc. Use for provider features RubyLLM
  doesn't wrap (e.g. `response_format: { type: "json_object" }` for plain JSON mode).
- `with_headers` merges custom HTTP headers (beta feature flags, etc.).

## Multimodal input — the `with:` kwarg

File type is auto-detected (Marcel); pass a path, URL, IO, or (in Rails) an
ActiveStorage attachment:

```ruby
chat.ask("Describe this logo.",        with: "path/to/ruby_logo.png")
chat.ask("What architecture is this?", with: "https://example.com/eiffel_tower.jpg")
chat.ask("Compare these screenshots.", with: ["v1.png", "v2.png"])
chat.ask("Analyze these files.",       with: ["report.pdf", "notes.txt", "clip.mp3"])
chat.ask("What's in this image?",      with: { image: "photo.jpg" })   # explicit type
```

Documented support (provider-dependent): images `.jpg .jpeg .png .gif .webp .bmp`;
video `.mp4 .mov .avi .webm` (Gemini/Vertex only); audio `.mp3 .wav .m4a .ogg .flac`
(e.g. `gpt-4o-audio-preview`, `gemini-2.5-flash`); documents `.pdf .txt .md .csv .json
.xml`; code `.rb .py .js .html .css` and more.

## Raw content blocks & prompt caching (v1.9.0+)

Pass provider-native content blocks when you need structure RubyLLM doesn't model:

```ruby
raw = RubyLLM::Content::Raw.new([
  { type: "text", text: "Reusable analysis prompt" },
  { type: "text", text: "Today's request: #{summary}" }
])
chat.add_message(role: :system, content: raw)
chat.ask(raw)   # ask / add_message / tool results / stream accumulators all accept Content::Raw
```

Anthropic prompt caching:

```ruby
system_block = RubyLLM::Providers::Anthropic::Content.new(
  "You are a release-notes assistant.",
  cache: true                                   # shorthand for cache_control: { type: 'ephemeral' }
)
chat.add_message(role: :system, content: system_block)
chat.ask(RubyLLM::Providers::Anthropic::Content.new(
  "Summarize the API changes.",
  cache_control: { type: "ephemeral", ttl: "1h" }
))
```

(Tool-level caching: `with_params cache_control: { type: "ephemeral" }` inside a
`RubyLLM::Tool` subclass — see [tools-and-schemas.md](tools-and-schemas.md).)

## Tokens & cost

```ruby
response.tokens.input        # excludes cache tokens as of v1.15 — see gotchas.md
response.tokens.output
response.tokens.cache_read   # v1.15+
response.tokens.cache_write  # v1.15+
response.tokens.thinking     # v1.10+

response.cost.input          # .output / .cache_read / .cache_write / .thinking / .total
chat.cost.total              # aggregate across the whole conversation (v1.15+)
```

## Callbacks

Additive callbacks (v1.15+, don't replace each other):

```ruby
chat.before_message   { print "Assistant > " }
chat.after_message    { |message| puts "done" }          # message may be nil on error
chat.before_tool_call { |tc| puts "calling #{tc.name} with #{tc.arguments}" }
chat.after_tool_result { |result| puts "tool returned: #{result}" }
```

Deprecated **replacing** handlers (older style): `on_new_message`, `on_end_message`,
`on_tool_call`, `on_tool_result`.

## Escape hatch: the raw HTTP response

```ruby
response.raw          # a Faraday::Response
response.raw.body
```
