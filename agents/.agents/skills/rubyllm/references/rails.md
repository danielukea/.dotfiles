# RubyLLM — Rails Integration

Sources: [rubyllm.com/rails/](https://rubyllm.com/rails/),
[rubyllm.com/upgrading/](https://rubyllm.com/upgrading/). The Rails layer is the **same
chat API** as plain Ruby (see [chat.md](chat.md)) mixed onto ActiveRecord models, plus
persistence and generators.

## Generators

```bash
bin/rails generate ruby_llm:install     # migrations (Chat/Message/ToolCall/Model),
                                        # model files with acts_as_*, initializer, ActiveStorage
bin/rails db:migrate
bin/rails ruby_llm:load_models          # v1.13+ — seed the Model table

bin/rails generate ruby_llm:chat_ui     # controllers, Turbo views, a stream job, routes → /chats

# custom class names / skip storage:
bin/rails generate ruby_llm:install chat:Conversation message:ChatMessage tool_call:FunctionCall model:AIModel
bin/rails generate ruby_llm:install --skip-active-storage

# v1.14+ scaffolding generators:
bin/rails generate ruby_llm:agent  Support   # app/agents/support_agent.rb + app/prompts/support_agent/instructions.txt.erb
bin/rails generate ruby_llm:tool   Weather   # app/tools/weather_tool.rb
bin/rails generate ruby_llm:schema Product   # app/schemas/product_schema.rb
```

## `acts_as_*` (new registry-based mode, default since v1.7)

```ruby
class Chat < ApplicationRecord
  acts_as_chat            # defaults: messages: :messages, model: :model
  belongs_to :user, optional: true
end

class Message < ApplicationRecord
  acts_as_message         # defaults: chat: :chat, tool_calls: :tool_calls, model: :model
  has_many_attached :attachments   # REQUIRED for file attachments
  # Do NOT add `validates :content, presence: true` — see gotchas.md
end

class ToolCall < ApplicationRecord
  acts_as_tool_call       # defaults: message: :message, result: :result
end

class Model < ApplicationRecord
  acts_as_model           # defaults: chats: :chats
end
```

Override association names via kwargs, e.g.
`acts_as_chat messages: :chat_messages, model: :ai_model`.

**Legacy mode** (pre-1.7, `config.use_new_acts_as = false` — must be set in
`config/application.rb`, see [gotchas.md](gotchas.md)):

```ruby
acts_as_chat      message_class: "Message", tool_call_class: "ToolCall"
acts_as_message   chat_class: "Chat", chat_foreign_key: "chat_id", tool_call_class: "ToolCall"
acts_as_tool_call message_class: "Message", message_foreign_key: "message_id"
```

## Conversation flow

```ruby
chat = Chat.create!(model: "gpt-5-nano", user: current_user)
response = chat.ask("What is the capital of France?")
chat.messages.last.content
chat.with_instructions("You are a Ruby expert.")
chat.with_instructions("Use short bullet points.", append: true)
```

Persistence on `ask`: saves the user message → calls `complete` → creates an **empty**
assistant message (on the first stream chunk, or before a non-streaming call) → on
success fills content + metadata, on failure destroys the empty row. This is why a
`content` presence validation breaks it.

Tokens/cost: `message.tokens.input/output/cache_read/cache_write`, `message.cost.total`,
`chat.cost.total` (v1.15+).

## Tools, schemas & attachments on a record

```ruby
chat.with_tool(Weather)
response = chat.ask("What's the weather in Paris?")
tc = chat.messages.second.tool_calls.first
tc.name; tc.arguments

chat.with_schema(PersonSchema).ask("Generate a person from Paris")

chat.ask("What's in this file?", with: "app/assets/images/diagram.png")
chat.ask("Analyze this",         with: params[:uploaded_file])
chat.ask("What's in this?",      with: user.profile_document)   # existing ActiveStorage attachment
```

## Streaming with Turbo / Hotwire

```ruby
class Message < ApplicationRecord
  acts_as_message
  broadcasts_to ->(m) { "chat_#{m.chat_id}" }

  def broadcast_append_chunk(content)
    broadcast_append_to "chat_#{chat_id}",
      target: "message_#{id}_content", partial: "messages/content", locals: { content: content }
  end
end

class ChatStreamJob < ApplicationJob
  def perform(chat_id)
    chat = Chat.find(chat_id)
    chat.complete do |chunk|
      msg = chat.messages.last
      msg.broadcast_append_chunk(chunk.content) if chunk.content && msg
    end
  end
end
```

View: `<%= turbo_stream_from "chat_#{@chat.id}" %>` + a `messages/_message` partial with
a `message_<id>_content` target div. The controller saves the user turn with
`@chat.add_message(role: :user, content: …)` then enqueues
`ChatStreamJob.perform_later(@chat.id)`. See [streaming.md](streaming.md) and the fiber
note in [gotchas.md](gotchas.md).

## Multi-tenant / provider overrides

```ruby
Chat.create!(model: "claude-sonnet-4-6", provider: "bedrock")

custom = RubyLLM.context { |c| c.openai_api_key = "your-tenant-api-key" }
Chat.create!(model: "gpt-5.4", context: custom)
```

## Overriding the persistence flow

Override the private hooks on the `acts_as_chat` model:

```ruby
class Chat < ApplicationRecord
  acts_as_chat
  private
  def persist_new_message = @message = messages.new(role: :assistant)
  def persist_message_completion(message)
    @message.assign_attributes(content: message.content, model: Model.find_by(model_id: message.model_id))
    @message.save!
    persist_tool_calls(message.tool_calls) if message.tool_calls.present?
  end
  def persist_tool_calls(tool_calls)
    tool_calls.each_value do |tc|
      attrs = tc.to_h; attrs[:tool_call_id] = attrs.delete(:id)
      @message.tool_calls.create!(**attrs)
    end
  end
end
```

## Version upgrades

Each significant version ships a generator; run it + `db:migrate`. From
[/upgrading/](https://rubyllm.com/upgrading/):

- **1.7** — string ids → DB-backed registry. `ruby_llm:upgrade_to_v1_7 [chat:… message:…
  tool_call:… model:…]`; set `config.use_new_acts_as = true` in `config/application.rb`;
  rename `acts_as_chat message_class:` → `messages:`; seed with `load_models`.
- **1.9** — raw content blocks: `cached_tokens`, `cache_creation_tokens`, `content_raw`
  (`ruby_llm:upgrade_to_v1_9`).
- **1.10** — extended thinking: `thinking_text`, `thinking_signature`, `thinking_tokens`
  (`ruby_llm:upgrade_to_v1_10`).
- **1.14** — `thought_signature` string→text, MySQL/MariaDB truncation fix
  (`ruby_llm:upgrade_to_v1_14`).
- **1.15** — token semantics normalized (`tokens.input` excludes cache tokens). No
  generator; see the token gotcha in [gotchas.md](gotchas.md).

## Fiber safety

For async/streaming-heavy apps (Rails 7.2.1+/8.x): `config.active_support.isolation_level
= :fiber` in `config/application.rb`, and prefer Falcon (see
[agents-and-async.md](agents-and-async.md)).
