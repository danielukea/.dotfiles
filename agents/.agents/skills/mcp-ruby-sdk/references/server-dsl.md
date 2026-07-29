# MCP Ruby SDK — Server API and DSL

## Module map

`require "mcp"` loads `json_rpc_handler`, `configuration`, `string_utils`, `transport`, `version`,
then autoloads the rest. Top-level entry points:

- `MCP::Server` (+ `server/capabilities.rb`, `pagination.rb`, `transports.rb`, `transports/`) — the JSON-RPC handler/registry
- `MCP::ServerContext`, `MCP::ServerSession` — per-request context and server→client requests
- `MCP::Tool` (+ `tool/`) — `Tool::Response`, `Tool::InputSchema`/`OutputSchema`
- `MCP::Prompt` (+ `prompt/`) — `Prompt::Argument`/`Message`/`Result`
- `MCP::Resource`, `MCP::ResourceTemplate` (+ `resource/` — contents, embedded)
- `MCP::Content` — `Content::Text`/`Image`/`Audio`/`EmbeddedResource`
- `MCP::Client` (+ `client/`) — see [client-and-transports.md](client-and-transports.md)
- `MCP.configure` → `MCP::Configuration`
- `MCP::Apps` — MCP Apps (UI) helpers, see [below](#mcp-apps-mcpapps)
- Supporting: `annotations.rb`, `icon.rb`, `cancellation.rb`/`cancelled_error.rb`, `progress.rb`,
  `trace_context.rb` (W3C trace propagation via `_meta`), `instrumentation.rb` (internal plumbing
  behind `around_request`), `methods.rb` (internal JSON-RPC method-name registry), `error_codes.rb`,
  `result_type.rb`

## Defining a server

`MCP::Server.new` verbatim signature:

```ruby
def initialize(
  description: nil, icons: [], name: "model_context_protocol", title: nil,
  version: DEFAULT_VERSION, website_url: nil, instructions: nil,
  tools: [], prompts: [], resources: [], resource_templates: [],
  server_context: nil, configuration: nil, capabilities: nil,
  page_size: nil, ttl_ms: nil, cache_scope: nil, transport: nil)
```

Public methods: `handle(request, session: nil)` / `handle_json(request, session: nil)` (see
[testing-and-gotchas.md](testing-and-gotchas.md#testing)); `define_tool`, `define_prompt`,
`define_custom_method(method_name:) { }`; handlers `resources_read_handler`,
`resources_subscribe_handler`, `resources_unsubscribe_handler`, `completion_handler`,
`roots_list_changed_handler`; notifications `notify_tools_list_changed`,
`notify_prompts_list_changed`, `notify_resources_list_changed`, `notify_log_message(...)`
(**deprecated** — see [testing-and-gotchas.md](testing-and-gotchas.md#gotchas)).

Note that `resources_subscribe_handler` / `resources_unsubscribe_handler` / `roots_list_changed_handler`
implement RPCs the `2026-07-28` spec **removed** — they're current API for this gem, which targets
`2025-11-25`. See [testing-and-gotchas.md](testing-and-gotchas.md#version--spec-compatibility--the-era-gap).

### Cache hints (`ttl_ms` / `cache_scope`)

Added in 0.24.0 per SEP-2549. Constructor kwargs plus writers (`server.ttl_ms = …`,
`server.cache_scope = …`), applied to List and Read results.

```ruby
server = MCP::Server.new(name: "my_server", tools: [SomeTool],
                         ttl_ms: 300_000, cache_scope: "public")
```

- `ttl_ms` must be `nil` or a **non-negative Integer**, else `ArgumentError`.
- `cache_scope` must be `nil`, `"public"`, or `"private"`, else `ArgumentError`.
- **Emission is opt-in:** with both `nil`, results serialize exactly as before. A result that already
  carries one of the fields is left alone.

**Conformance gap to know:** `2026-07-28` makes these fields **required** on cacheable results, and
requires them on `server/discover` too — the gem sends them only when configured, and its `discover`
never includes them. Semantics of the two fields:
[caching.md](../../model-context-protocol/references/caching.md).

### `server/discover`

Registered as `Methods::SERVER_DISCOVER` → `Server#discover` (0.24.0, SEP-2575). Deliberately
**state-free and idempotent**: it stores no client info, does not mark the session initialized, and
answers regardless of capability declarations or initialization state — so a client can probe before
(or instead of) `initialize`. `serverInfo` is returned unfiltered because discovery precedes version
negotiation.

```ruby
{ supportedVersions: Configuration::SUPPORTED_STABLE_PROTOCOL_VERSIONS,
  capabilities: capabilities, serverInfo: server_info, instructions: instructions }.compact
```

**`supportedVersions` tops out at `2025-11-25`** — that's what tells a modern client to fall back. No
`ttlMs`/`cacheScope`, and the source still calls the revision a "draft."

### MCP Apps (`MCP::Apps`)

Server-side helpers for the MCP Apps extension (0.24.0, SEP-1865):

- `RESOURCE_MIME_TYPE = "text/html;profile=mcp-app"` — UI template resources **MUST** use this
  parameterized MIME type.
- `Apps.capability(mime_types: [RESOURCE_MIME_TYPE])` — build the capability declaration.
- `Apps.ui_resource(uri:, name:, mime_type: RESOURCE_MIME_TYPE, **rest)` — a UI resource, defaulting to
  a `ui://` URI and that MIME type.
- `Apps.tool_meta(resource_uri:, visibility: nil, meta: nil, legacy: false)` — the `_meta` a tool uses
  to point at its UI resource.
- `Apps.client_supports?(client_capabilities, mime_type: RESOURCE_MIME_TYPE)` — graceful-degradation
  check; MCP Apps is an opt-in extension, so **always branch on this** rather than assuming support.

Extension negotiation is protocol-side:
[versioning-and-extensions.md](../../model-context-protocol/references/versioning-and-extensions.md#extensions).

**Minimal working server** (verbatim, `examples/stdio_server.rb`):

```ruby
require "mcp"

class ExampleTool < MCP::Tool
  description "A simple example tool that adds two numbers"
  input_schema(
    properties: { a: { type: "number" }, b: { type: "number" } },
    required: ["a", "b"],
  )
  class << self
    def call(a:, b:)
      MCP::Tool::Response.new([{ type: "text", text: "The sum of #{a} and #{b} is #{a + b}" }])
    end
  end
end

class ExamplePrompt < MCP::Prompt
  description "A simple example prompt that echoes back its arguments"
  arguments [
    MCP::Prompt::Argument.new(name: "message", description: "The message to echo back", required: true),
  ]
  class << self
    def template(args, server_context:)
      MCP::Prompt::Result.new(
        messages: [MCP::Prompt::Message.new(role: "user", content: MCP::Content::Text.new(args[:message]))],
      )
    end
  end
end

server = MCP::Server.new(
  name: "example_server", version: "1.0.0",
  tools: [ExampleTool], prompts: [ExamplePrompt],
  resources: [MCP::Resource.new(
    uri: "https://test_resource.invalid", name: "test-resource",
    mime_type: "text/plain")],
)

server.define_tool(
  name: "echo", description: "Echoes back its arguments",
  input_schema: { properties: { message: { type: "string" } }, required: ["message"] },
) do |message:|
  MCP::Tool::Response.new([{ type: "text", text: "Hello from echo tool! Message: #{message}" }])
end

server.resources_read_handler do |params|
  [{ uri: params[:uri], mimeType: "text/plain", text: "Hello, world! URI: #{params[:uri]}" }]
end

transport = MCP::Server::Transports::StdioTransport.new(server)
transport.open
```

**Trap:** handler arity is inspected — `call(a:, b:)` above omits `server_context:` while
`template(args, server_context:)` takes it. The SDK only injects `server_context:` when the
handler declares it; don't assume every callback receives it.

## Defining Tools

Three interchangeable styles:

```ruby
# a) class-based
class MyTool < MCP::Tool
  title "My Tool"
  description "Performs specific functionality"
  input_schema(properties: { message: { type: "string" } }, required: ["message"])
  output_schema(properties: { result: { type: "string" } }, required: ["result"])
  annotations(read_only_hint: true, idempotent_hint: true)
  def self.call(message:, server_context:)
    MCP::Tool::Response.new([{ type: "text", text: "OK" }])
  end
end

# b) standalone block
tool = MCP::Tool.define(name: "my_tool", description: "...") { |args, server_context:| ... }

# c) server-level block
server.define_tool(name: "my_tool", description: "...") { |args| ... }
```

Class-macro DSL (each backed by a `NOT_SET`-sentinel getter/setter): `tool_name` (validated,
**1–128 chars, `[A-Za-z0-9_.-]`**), `title`, `description`, `icons`, `meta`, `input_schema`
(`{properties:, required:}` Hash or an `InputSchema` object), `output_schema` (for structured
results), `annotations` (wraps a hash into `Annotations`; hints like `read_only_hint`/
`idempotent_hint`), `call(*args, server_context: nil)` (base class raises `NotImplementedError`).

`InputSchema` (`tool/input_schema.rb`) validates via `json_schemer`: `missing_required_arguments?`,
`missing_required_arguments`, `validate_arguments` (raises `ValidationError`). Gated by config
`validate_tool_call_arguments` (default `true`); output validated by `validate_tool_call_results`
(default `false`).

`Tool::Response` (`tool/response.rb`):

```ruby
def initialize(content = nil, deprecated_error = NOT_GIVEN, error: false,
               structured_content: nil, meta: nil)
# to_h => { content:, isError: error?, structuredContent:, _meta: }.compact
```

The second positional (`deprecated_error`) is legacy — use the `error:` keyword, not a second
positional arg, to set the error flag. `content` accepts an array of plain hashes
(`{type: "text", text: ...}`) **or** `MCP::Content::*` objects — the SDK's own README mixes both,
so either is idiomatic.

## Defining Resources

**Static** — `MCP::Resource.new`:

```ruby
def initialize(uri:, name:, title: nil, description: nil, icons: [],
               mime_type: nil, annotations: nil, size: nil, meta: nil)
```

`to_h` emits camelCase (`mimeType`, `_meta`) and drops nils. Pass via `resources: [...]` on the
server, and read it via `server.resources_read_handler { |params| [{ uri:, mimeType:, text: }] } }`.

**Templated** — `MCP::ResourceTemplate.new`:

```ruby
def initialize(uri_template:, name:, title: nil, description: nil, icons: [],
               mime_type: nil, annotations: nil, meta: nil)
```

Pass via `resource_templates: [...]`; `to_h` emits `uriTemplate`.

**Class-based style** (added 0.24.0) — both `Resource` and `ResourceTemplate` now support subclassing
with a class-level DSL, alongside `.define` and `.new`, mirroring how Tools and Prompts already worked:

```ruby
class ConfigResource < MCP::Resource
  uri "file:///config.json"
  name "config"
  mime_type "application/json"
end

# or the block form
MCP::Resource.define(uri: "file:///config.json", name: "config") { ... }
```

Subscriptions: `resources_subscribe_handler` / `resources_unsubscribe_handler`, pushed with
`server.notify_resources_list_changed`. Also see `resource/contents`, `resource/embedded`, and
`MCP::Content::EmbeddedResource.new(resource, ...)`.

## Defining Prompts

```ruby
class MyPrompt < MCP::Prompt
  prompt_name "my_prompt"
  title "My Prompt"
  description "..."
  arguments [MCP::Prompt::Argument.new(name: "message", required: true)]
  def self.template(args, server_context:)
    MCP::Prompt::Result.new(
      description: "Response",
      messages: [MCP::Prompt::Message.new(role: "user", content: MCP::Content::Text.new("..."))])
  end
end
```

DSL macros: `prompt_name`, `title`, `description`, `icons`, `arguments`, `meta`; abstract
`self.template(args, server_context: nil)`; `validate_arguments!`. Also available:
`MCP::Prompt.define(name:, title:, description:, arguments:, &block)` and
`server.define_prompt(name:, title:, description:, arguments:, &block)`.

Nested value classes:
- `Prompt::Argument.new(name:, title: nil, description: nil, required: false)`
- `Prompt::Message.new(role:, content:)` → `to_h = { role:, content: content.to_h }`
- `Prompt::Result.new(description: nil, messages: [], meta: nil)`

Content classes (`content.rb`), all emit a `type:` key:
- `Content::Text.new(text, annotations: nil, meta: nil)`
- `Content::Image.new(data, mime_type, annotations: nil, meta: nil)` → `mimeType`
- `Content::Audio.new(data, mime_type, annotations: nil, meta: nil)`
- `Content::EmbeddedResource.new(resource, annotations: nil, meta: nil)`

## Configuration & instrumentation

Global via `MCP.configure { |config| ... }` (`MCP::Configuration`), or per-server via
`MCP::Server.new(configuration:)`. Configs `.merge` (other's explicitly-set values win).

| Attribute | Default | Notes |
| --- | --- | --- |
| `exception_reporter` | no-op | `->(exception, server_context) { }` |
| `around_request` | pass-through | `->(data, &request_handler) { }` wraps every request |
| `instrumentation_callback` | no-op | **deprecated** — use `around_request` |
| `protocol_version` | `LATEST_STABLE_PROTOCOL_VERSION` (`"2025-11-25"`) | see [testing-and-gotchas.md](testing-and-gotchas.md#version--spec-compatibility--the-era-gap) for the full negotiation story |
| `validate_tool_call_arguments` | `true` | validates tool inputs against `input_schema` |
| `validate_tool_call_results` | `false` | validates structured results against `output_schema` |

```ruby
MCP.configure do |config|
  config.exception_reporter = ->(exception, server_context) {
    Bugsnag.notify(exception) { |r| r.add_metadata(:model_context_protocol, server_context) }
  }
  config.around_request = ->(data, &request_handler) {
    logger.info("Start: #{data[:method]}")
    request_handler.call
    logger.info("Done: #{data[:method]}, tool: #{data[:tool_name]}")
  }
end
```

## Server-side advanced (`server_context`)

Inside a tool/prompt `call`/`template`, the injected `server_context:` exposes the server→client
requests defined in [primitives.md](../../model-context-protocol/references/primitives.md).
**Verified from `lib/mcp/server_context.rb`:**

- **Cancellation:** `cancelled?` (`!!@cancellation&.cancelled?`), `raise_if_cancelled!`
- **Progress:** `report_progress(progress, total: nil, message: nil)`
- **Elicitation:** `create_form_elicitation(**kwargs)`, `create_url_elicitation(**kwargs)`, `notify_elicitation_complete(**kwargs)`
- **Connectivity:** `ping`, `notify_resources_updated(uri:)`
- **Sampling:** `create_sampling_message(**kwargs)` — carries a YARD `@deprecated` tag citing MCP
  protocol version `2026-07-28` (SEP-2577)
- **Roots:** `list_roots` — same annotation
- **Logging:** the logging helpers carry the same annotation

**The deprecation status, stated precisely** (this reverses an earlier reading of the SDK source):

- `2026-07-28` **is published**, so "Roots, Sampling, and Logging are deprecated in MCP" is now a
  **correct protocol fact**, not the SDK getting ahead of the spec. Earliest removal is a revision
  released on or after 2027-07-28. See
  [versioning-and-extensions.md](../../model-context-protocol/references/versioning-and-extensions.md#currently-deprecated).
- But these annotations are **YARD doc tags only — they emit no runtime warning.** `ROADMAP.md` says
  warnings land "in a future minor release," and all three stay fully supported through 1.x with no
  removal scheduled.
- **Elicitation is not deprecated** and is not part of these annotations.
- In the modern protocol these three are delivered via **MRTR**, not server-initiated requests — so
  these `server_context` helpers have no `2026-07-28` equivalent. They work because the gem speaks
  `2025-11-25`.

Unrecognized calls fall through `method_missing` to the underlying context object — don't assume the
list above is exhaustive if you see a call that isn't here.

## Progress, Cancellation, and Tracing

**Progress** — `MCP::Progress`, verified from `lib/mcp/progress.rb`:

```ruby
def initialize(notification_target:, progress_token:, related_request_id: nil)
def report(progress, total: nil, message: nil)
```

`report` is a deliberate no-op if either `@progress_token` or `@notification_target` is absent —
you can call it unconditionally in a tool's `call` method without checking whether the caller
asked for progress notifications first.

**Cancellation** — `MCP::Cancellation`, verified from `lib/mcp/cancellation.rb` and
`lib/mcp/cancelled_error.rb`:

```ruby
MCP::Cancellation.new(request_id: nil)
# cancelled?                     # => bool
# cancel(reason: nil)            # marks cancelled, runs registered callbacks
# on_cancel { |reason| ... }     # registers a callback, invoked synchronously on first #cancel
# off_cancel(handle)              # deregisters a callback
# raise_if_cancelled!            # raises MCP::CancelledError if already cancelled
# reason, request_id             # attr_readers

MCP::CancelledError.new(message = "Request was cancelled", request_id: nil, reason: nil)
# < StandardError
```

Pattern for a long-running tool: check `server_context.cancelled?` (or call
`raise_if_cancelled!`) at safe checkpoints inside a loop, and call `report_progress` between
checkpoints. This is the SDK-level machinery behind cooperative cancellation described at the
protocol level in `model-context-protocol`'s
[primitives.md](../../model-context-protocol/references/primitives.md#progress-and-cancellation).

## Distributed tracing (`_meta`, `MCP::TraceContext`)

Verified from `lib/mcp/trace_context.rb`: `MCP::TraceContext` defines the three
[W3C Trace Context](https://www.w3.org/TR/trace-context/) keys the SDK reserves and guarantees to
pass through on every request's `_meta`, exposed as a frozen constant:

```ruby
MCP::TraceContext::META_KEYS
# => ["traceparent", "tracestate", "baggage"]
```

There's no dedicated API beyond the constant — a handler reads these directly out of
`server_context[:_meta]` and bridges them to whatever tracing library it uses (the SDK's own docs
point at the `opentelemetry-ruby` gems as the natural pairing). This is what lets you correlate an
OpenTelemetry span across an MCP call without the transport itself knowing anything about tracing.
See `model-context-protocol`'s [primitives.md](../../model-context-protocol/references/primitives.md)
for the general `_meta` convention this relies on.

## Completion

Wiring a completion handler for prompt-argument/resource-template autocomplete (protocol-level
shape is in `model-context-protocol`'s
[primitives.md](../../model-context-protocol/references/primitives.md#completion)):

```ruby
server.completion_handler do |params|
  # params[:ref] is {"type" => "ref/prompt", "name" => ...} or {"type" => "ref/resource", "uri" => ...}
  # params[:argument] is {"name" => ..., "value" => ...} — the partial value being typed
  # params[:context] may carry already-resolved sibling arguments for dependent completion
  { completion: { values: [...], total: nil, hasMore: false } }
end
```

## Sources (fetched 2026-07-29, `main`, gem v1.0.0)

- https://raw.githubusercontent.com/modelcontextprotocol/ruby-sdk/main/README.md
- https://raw.githubusercontent.com/modelcontextprotocol/ruby-sdk/main/lib/mcp.rb
- https://raw.githubusercontent.com/modelcontextprotocol/ruby-sdk/main/lib/mcp/server.rb (constructor incl. `ttl_ms`/`cache_scope`; `Server#discover`)
- https://raw.githubusercontent.com/modelcontextprotocol/ruby-sdk/main/lib/mcp/apps.rb (MCP Apps helpers)
- https://raw.githubusercontent.com/modelcontextprotocol/ruby-sdk/main/lib/mcp/tool.rb
- https://raw.githubusercontent.com/modelcontextprotocol/ruby-sdk/main/lib/mcp/tool/input_schema.rb
- https://raw.githubusercontent.com/modelcontextprotocol/ruby-sdk/main/lib/mcp/tool/response.rb
- https://raw.githubusercontent.com/modelcontextprotocol/ruby-sdk/main/lib/mcp/prompt.rb
- https://raw.githubusercontent.com/modelcontextprotocol/ruby-sdk/main/lib/mcp/prompt/argument.rb
- https://raw.githubusercontent.com/modelcontextprotocol/ruby-sdk/main/lib/mcp/prompt/message.rb
- https://raw.githubusercontent.com/modelcontextprotocol/ruby-sdk/main/lib/mcp/prompt/result.rb
- https://raw.githubusercontent.com/modelcontextprotocol/ruby-sdk/main/lib/mcp/resource.rb
- https://raw.githubusercontent.com/modelcontextprotocol/ruby-sdk/main/lib/mcp/resource_template.rb
- https://raw.githubusercontent.com/modelcontextprotocol/ruby-sdk/main/lib/mcp/progress.rb
- https://raw.githubusercontent.com/modelcontextprotocol/ruby-sdk/main/lib/mcp/cancellation.rb
- https://raw.githubusercontent.com/modelcontextprotocol/ruby-sdk/main/lib/mcp/cancelled_error.rb
- https://raw.githubusercontent.com/modelcontextprotocol/ruby-sdk/main/lib/mcp/trace_context.rb
- https://raw.githubusercontent.com/modelcontextprotocol/ruby-sdk/main/lib/mcp/content.rb
- https://raw.githubusercontent.com/modelcontextprotocol/ruby-sdk/main/lib/mcp/configuration.rb
- https://raw.githubusercontent.com/modelcontextprotocol/ruby-sdk/main/examples/stdio_server.rb
- https://raw.githubusercontent.com/modelcontextprotocol/ruby-sdk/main/lib/mcp/server_context.rb

If re-verifying against a newer release: `lib/mcp/version.rb` gives the current gem version, and
`CHANGELOG.md` lists what changed. Post-1.0 the signatures above are stable across minors *except* for
spec-conformance/security/defect fixes (`VERSIONING.md`), so the things most likely to move are exactly
the conformance gaps flagged here — `ttlMs`/`cacheScope` becoming non-optional, `server/discover`
gaining cache hints, and anything tied to the
[era gap](testing-and-gotchas.md#version--spec-compatibility--the-era-gap).
