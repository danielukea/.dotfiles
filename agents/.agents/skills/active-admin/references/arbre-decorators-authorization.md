# Arbre Components, Decorators & Authorization Adapters

## Arbre Components {#arbre-components}

Arbre is the Ruby DSL for building HTML that `index`/`show`/`content`/custom-page blocks are
written in. ActiveAdmin's own docs cover only these built-ins — general tag helpers (`div`,
`span`, `h2`, `ul`/`li`) and authoring your own `Arbre::Component` subclass are Arbre-gem-level
knowledge, not covered here.

```ruby
text_node "&nbsp;".html_safe   # insert raw text/whitespace within a component

panel "Post Details" do
  render partial: "details", locals: { post: post }
end

columns do
  column span: 2, max_width: "200px", min_width: "100px" do
    span "Content"
  end
  column class: "important" do
    span "More content"
  end
end

table_for order.payments, i18n: Payment do
  column(:payment_type) { |payment| payment.payment_type.titleize }
  column "Received On", :created_at
end

status_tag 'In Progress'
status_tag true                                  # renders "Yes"
status_tag 'active', class: 'important', label: 'on'

tabs do
  tab :active do
    table_for orders.active {}
  end
  tab :inactive, html_options: { class: "css_class" } do
    table_for orders.inactive {}
  end
end
```

## Decorators

`decorate_with` wires a decorator (Draper recommended, not required) into index/show:

```ruby
# app/decorators/post_decorator.rb
class PostDecorator < Draper::Decorator
  delegate_all

  def image
    h.image_tag model.image_url
  end
end

# app/admin/post.rb
ActiveAdmin.register Post do
  decorate_with PostDecorator

  index do
    column :title
    column :image
    actions
  end
end
```

A decorator class must accept the record in its initializer and respond to whatever methods
index/show call on it. Non-Draper example:

```ruby
class PostDecorator
  attr_reader :post
  delegate_missing_to :post

  def initialize(post)
    @post = post
  end
end
```

**Forms are not decorated by default** — opt in with `decorate: true`:

```ruby
form decorate: true do |f|
  # ...
end
```

**Delegate `to_param`** on a custom decorator or `show`/`edit`/`destroy` links 404 (routing calls
`to_param` on whatever it's handed):

```ruby
delegate :to_param, to: :post
```

**Implement `decorated?` and `model`** if you use the Comments feature:

```ruby
def decorated?
  true
end

def model
  post
end
```

Full detail on all three decorator gotchas: [gotchas.md](gotchas.md#decorators).

## Authorization Adapter

Default behavior with no adapter configured: everything is permitted. Plugging one in makes
`#authorized?` get called on every action.

### Writing a custom adapter

Subclass `ActiveAdmin::AuthorizationAdapter`, implement `authorized?(action, subject)`:

```ruby
class OnlyAuthorsAuthorization < ActiveAdmin::AuthorizationAdapter
  def authorized?(action, subject = nil)
    case subject
    when normalized(Post)
      action == :update || action == :destroy ? subject.author == user : true
    else
      true
    end
  end
end
```

Register it — globally or per-namespace — in the initializer (see
[setup-and-config.md](setup-and-config.md#authorization)).

**Action categories:** `:read` (menu items, index, show), `:create` (new + create), `:update`
(edit + update), `:destroy`. Constants: `ActiveAdmin::Authorization::READ`, etc.

**Current user** is available as `user` inside the adapter:

```ruby
class OnlyAdmins < ActiveAdmin::AuthorizationAdapter
  def authorized?(action, subject = nil)
    user.admin?
  end
end
```

**Scoping collections** — implement `scope_collection`:

```ruby
class OnlyMyAccount < ActiveAdmin::AuthorizationAdapter
  def authorized?(action, subject = nil)
    subject.account == user.account
  end

  def scope_collection(collection, action = Auth::READ)
    collection.where(account_id: user.account_id)
  end
end
```

**Pages** (e.g. restricting the Dashboard) — `subject` can be an `ActiveAdmin::Page`:

```ruby
class OnlyDashboard < ActiveAdmin::AuthorizationAdapter
  def authorized?(action, subject = nil)
    case subject
    when ActiveAdmin::Page
      action == :read && subject.name == "Dashboard" && subject.namespace.name == :admin
    else
      false
    end
  end
end
```

### Checking authorization in your own code

```ruby
index do
  column '' do |post|
    link_to 'Edit', admin_post_path(post) if authorized? :update, post
  end
end

member_action :publish, method: :post do
  post = Post.find(params[:id])
  authorize! :publish, post    # raises if not authorized
  post.publish!
  redirect_to [:admin, post], notice: "Post has been published"
end

action_item :publish, only: :show do
  if !post.published? && authorized?(:publish, post)
    link_to "Publish", publish_admin_post_path(post), method: :post
  end
end
```

`authorized?` returns a boolean; `authorize!` raises.

### CanCanCan adapter

```ruby
config.authorization_adapter = ActiveAdmin::CanCanAdapter
config.on_unauthorized_access = :access_denied
config.cancan_ability_class   = "MyCustomAbility"
```

```ruby
class ApplicationController < ActionController::Base
  protect_from_forgery

  def access_denied(exception)
    redirect_to admin_organizations_path, alert: exception.message
  end
end
```

```ruby
# app/models/ability.rb
class Ability
  include CanCan::Ability

  def initialize(user)
    can :manage, Post
    can :read, User
    can :manage, User, id: user.id
    can :read, ActiveAdmin::Page, name: "Dashboard", namespace_name: "admin"
  end
end
```

### Pundit adapter

```ruby
config.authorization_adapter = ActiveAdmin::PunditAdapter
```

```ruby
class ApplicationController < ActionController::Base
  include Pundit
  after_action :verify_authorized, except: :index, unless: :active_admin_controller?
  after_action :verify_policy_scoped, only: :index, unless: :active_admin_controller?

  def active_admin_controller?
    is_a?(ActiveAdmin::BaseController)
  end
end
```

Batch `:destroy` needs a `destroy_all?` method on the policy class — see
[gotchas.md](gotchas.md#authorization) for both Pundit gotchas.
