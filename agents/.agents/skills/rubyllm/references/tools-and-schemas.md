# RubyLLM — Tools & Structured Output

Sources: [rubyllm.com/tools/](https://rubyllm.com/tools/),
[rubyllm.com/chat/](https://rubyllm.com/chat/) (structured-output section — there is no
standalone `/structured-output/` or `/schema/` page).

## Tools — let the model call your code

Subclass `RubyLLM::Tool`, describe it, implement `execute`:

```ruby
class Weather < RubyLLM::Tool
  desc "Gets current weather for a location"   # `description` is an alias

  def execute(latitude:, longitude:)           # v1.15+: params inferred from the signature
    url = "https://api.open-meteo.com/v1/forecast?latitude=#{latitude}&longitude=#{longitude}&current=temperature_2m"
    JSON.parse(Faraday.get(url).body)
  rescue => e
    { error: e.message }                        # recoverable errors: return an error hash
  end
end
```

### Declaring parameters — four ways

1. **Signature inference** (v1.15+) — just declare keyword args on `execute`.
2. **`param` helper** (flat args):
   ```ruby
   param :units, type: :string, desc: "metric or imperial", required: false
   ```
3. **`params do … end` DSL** (v1.9+) for nested objects/arrays/enums/unions:
   ```ruby
   params do
     object :window, description: "Time window" do
       string :start, description: "ISO8601 start time"
     end
     array :participants, of: :string, description: "Emails"
     any_of :format, description: "Optional format" do
       string enum: %w[virtual in_person]
       null
     end
   end
   ```
4. **Manual JSON Schema** — `params type: "object", properties: {…}, required: […],
   additionalProperties: false, strict: true`.

`with_params` inside a tool attaches provider-specific metadata (e.g. Anthropic
`cache_control`). Custom initializers are fine — inject dependencies and register an
instance:

```ruby
class DocumentSearch < RubyLLM::Tool
  def initialize(db) = @db = db
  def execute(query:, limit: 5) = @db.search(query, limit)
end
chat.with_tool(DocumentSearch.new(MyDatabase))
```

### Registering & controlling tools

```ruby
chat.with_tool(Weather)                      # class or instance
chat.with_tools(Weather, StockPrice, replace: true)
chat.with_tools(Weather, choice: :auto,      # :auto | :required | :none | :<tool_name> (v1.13+)
                          calls: :many,       # :many | :one | 1
                          concurrency: true)  # true | :threads | :fibers (v1.16+)
```

Global concurrency: `RubyLLM.configure { |c| c.tool_concurrency = true }`. Tool
callbacks live on the chat: `before_tool_call { |tc| }`, `after_tool_result { |r| }`
(see [chat.md](chat.md)).

### The `execute` return contract

- Return a value (String/Hash/etc.) → fed back to the model.
- Return `{ error: "…" }` → recoverable error the model can react to.
- Return `RubyLLM::Content.new("text", [file_paths])` → rich/attached content.
- Call `halt "message"` → **short-circuits**: `"message"` is the result and the LLM's
  follow-up pass is skipped (see [gotchas.md](gotchas.md)).
- `raise` → unrecoverable failure (bad config, DB down).

### Security

Treat every `execute` argument as untrusted model output. **Never** `eval` / `system` /
`send` / raw-interpolate into SQL — the docs' own `eval(expression)` calculator is a
footgun. Debug with `RUBYLLM_DEBUG=true`.

## Structured output — force a JSON shape

Subclass `RubyLLM::Schema` (from the `ruby_llm-schema` gem) and attach with
`with_schema`; `response.content` comes back already parsed into a Hash:

```ruby
class PersonSchema < RubyLLM::Schema
  string  :name, description: "Full name"
  integer :age,  description: "Age in years"
  string  :city, required: false
end

chat = RubyLLM.chat.with_schema(PersonSchema)
response = chat.ask("Generate a person named Alice who is 30")
response.content            # => {"name" => "Alice", "age" => 30}
```

Nested DSL primitives: `string`, `integer`, `number`, `boolean`, `array (of: / do…end)`,
`object (do…end)`, `any_of (do…end)`, `null`, plus `description:` / `required:` /
`enum:`.

```ruby
class LanguagesSchema < RubyLLM::Schema
  array :languages do
    object do
      string  :name
      integer :year
    end
  end
end
```

Manual JSON Schema hash (note the OpenAI requirement):

```ruby
schema = {
  type: "object",
  properties: { name: { type: "string" }, hobbies: { type: "array", items: { type: "string" } } },
  required: ["name", "hobbies"],
  additionalProperties: false     # REQUIRED for OpenAI
}
chat.with_schema(schema)                       # or { name: "PersonSchema", schema: {…} }
chat.with_schema(nil)                          # remove mid-conversation
```

- `with_schema` guarantees the **shape**; plain JSON mode
  (`with_params(response_format: { type: "json_object" })`) only guarantees valid JSON.
- Documented provider support: OpenAI GPT-4o+, Anthropic Claude 4.5+ (Haiku/Sonnet/Opus),
  Gemini 1.5 Pro/Flash+. Works with tools, Agents, and Rails-persisted chats.
- The `ruby_llm:schema` Rails generator scaffolds `app/schemas/*` (see [rails.md](rails.md)).
