# RubyLLM — Streaming

Source: [rubyllm.com/streaming/](https://rubyllm.com/streaming/).

## Streaming is a block, not a flag

There is no `stream: true`. Passing a block to `ask` enables streaming; the block
receives `RubyLLM::Chunk` objects as they arrive, and `ask` **still returns the fully
accumulated final `RubyLLM::Message`** once the stream ends.

```ruby
chat = RubyLLM.chat
final = chat.ask("Write a short haiku about programming.") do |chunk|
  print chunk.content
end
puts final.content            # the complete message
```

## `RubyLLM::Chunk`

`Chunk` inherits from `RubyLLM::Message`. Fields:

- `chunk.content` — the text fragment (may be `nil`/empty).
- `chunk.role` — always `:assistant`.
- `chunk.model_id`.
- `chunk.tool_calls` — hash of partial/complete tool-call info (arguments may stream in
  incrementally).
- `chunk.tokens&.input` / `&.output` / `&.cache_read` / `&.cache_write` — cumulative,
  and typically only accurate on the **final** chunk (read totals from the returned
  `Message`, not an early chunk).
- `chunk.thinking` — optional reasoning output.

## Streaming with tools

The stream arrives in phases: initial text → tool-call chunk(s) → a pause while
`Tool#execute` runs → resumed stream with the final answer.

```ruby
chat = RubyLLM.chat(model: "gpt-5.4").with_tool(Weather)
chat.ask("What's the weather in Berlin (52.52, 13.40)?") do |chunk|
  if chunk.tool_calls
    puts "\n[TOOL CALL: #{chunk.tool_calls.values.first.name}]"
  elsif chunk.content
    print chunk.content
  end
end
```

## Errors mid-stream

Provider errors raised during streaming surface as `RubyLLM::Error` subclasses after
the block finishes / is interrupted (see [error-handling.md](error-handling.md)):

```ruby
begin
  chat.ask("Generate a long response…") { |chunk| print chunk.content }
rescue RubyLLM::Error => e
  puts "#{e.class}: #{e.message}"
end
```

## Web framework integration

- **Rails + Turbo Streams** — run `chat.ask(…) { |chunk| … }` inside a background
  `ActiveJob` and broadcast each chunk with `Turbo::StreamsChannel.broadcast_replace_to`
  (or a custom `broadcast_append_to`). Full pattern with `acts_as_message` and
  `broadcasts_to` in [rails.md](rails.md).
- **Sinatra + SSE** — `stream(:keep_open) { |out| chat.ask(…) { |chunk| out << "data:
  #{chunk.content.to_json}\n\n" } }`.

For non-blocking concurrency around streaming, see [agents-and-async.md](agents-and-async.md)
and the fiber-isolation note in [gotchas.md](gotchas.md).
