# RubyCMS

Reusable Rails engine for a CMS-style admin: content blocks, visual editor, versioning, pluggable dashboard, permissions, analytics, and visitor error tracking.

Your app owns product features (pages, models, business logic); RubyCMS manages content workflows and admin screens.

## Features

- **Content blocks** -- rich text, plain text, images, links, and lists with locale support
- **Content block versioning** -- automatic version history with rollback and side-by-side diffs
- **Visual editor** -- inline editing on live page previews
- **Pluggable dashboard** -- registry-based blocks with permission gating and host-app extensibility
- **Permissions** -- key-based access control with templates and per-user assignment
- **Admin page generator** -- one command to scaffold a new admin page with nav, permission, and route
- **Named icon registry** -- 20+ Heroicons by name, no SVG copy-pasting
- **Settings** -- DB-backed admin settings with categories and UI
- **Analytics** -- Ahoy-powered visit/event tracking with dashboard drill-downs
- **Visitor error tracking** -- automatic 404/500 capture with admin overview

## Quick Start

```bash
# Add to Gemfile
gem "ruby_cms"

# Install
rails g ruby_cms:install
rails db:migrate
rails ruby_cms:seed_permissions
rails ruby_cms:setup_admin
```

The install generator sets up the initializer, mounts the engine at `/admin`, runs migrations, configures Tailwind, Stimulus, Action Text, and Ahoy.

Visit `/admin` and sign in with the admin user you configured.

## Content Blocks

Use the `content_block` helper in any view:

```erb
<%= content_block("hero_title", default: "Welcome") %>
<%= content_block("footer", cache: true) %>
```

### Content Types

| Type | Description |
|------|-------------|
| `text` | Plain text string |
| `rich_text` | Action Text rich content (HTML) |
| `image` | Attached image via Active Storage |
| `link` | URL string |
| `list` | JSON array or newline-separated items |

### Placeholders and Attributes

`content_block` wraps output for the visual editor. For HTML attributes, use `wrap: false`:

```erb
<%= text_field_tag :name, nil,
  placeholder: content_block("contact.placeholder", wrap: false, fallback: "Your name") %>
```

Or use `content_block_text` which never wraps:

```erb
<meta name="description" content="<%= content_block_text("meta_desc", fallback: "Default") %>">
```

### List Items

```erb
<% content_block_list_items("badges", fallback: ["Ruby", "Rails"]).each do |badge| %>
  <%= tag.span badge, class: "badge" %>
<% end %>
```

### Multi-locale Support

Content blocks have a `locale` field. The CMS groups blocks by key prefix across locales for easy management.

## Content Block Versioning

Versions are created automatically on every meaningful change:

```ruby
block = ContentBlock.create!(key: "hero", title: "Welcome", content: "Hello",
                              content_type: "text", locale: "en")
block.versions.count  # => 1 (event: "create")

block.update!(title: "Welcome!")
block.versions.count  # => 2 (event: "update")

block.update!(published: false)
block.versions.last.event  # => "unpublish"
```

### Events

| Event | When |
|-------|------|
| `create` | Block is first created |
| `update` | Title, content, or content_type changes |
| `publish` | `published` changes to `true` |
| `unpublish` | `published` changes to `false` |
| `rollback` | `rollback_to_version!` is called |
| `visual_editor` | Edit via the visual editor |

### Rollback

```ruby
old_version = block.versions.first
block.rollback_to_version!(old_version, user: current_user)
# Creates a new version with event: "rollback"
# Restores title, content, content_type, published, and rich_content
```

### Admin UI

- **Version history** link on each content block show page
- **Timeline view** with colored event badges
- **Side-by-side diff** (old vs new, red/green)
- **Rollback button** with confirmation

### Routes

```
GET  /admin/content_blocks/:id/versions        # index (HTML + JSON)
GET  /admin/content_blocks/:id/versions/:vid    # show with diff
POST /admin/content_blocks/:id/versions/:vid/rollback
```

## Visual Editor

Configure preview templates in `config/initializers/ruby_cms.rb`:

```ruby
RubyCms.configure do |c|
  c.preview_templates = { "home" => "pages/home", "about" => "pages/about" }
  c.preview_data = ->(page_key, view) { { products: Product.limit(5) } }
end
```

Open **Admin > Visual editor**, pick a page, and click content blocks to edit them inline.

## Dashboard

The dashboard uses a registry-based block system. Each block is a partial with optional permission gating and data injection.

### Default Blocks

| Block | Section | Permission |
|-------|---------|------------|
| Content blocks stats | stats | `manage_content_blocks` |
| Users stats | stats | `manage_permissions` |
| Permissions stats | stats | `manage_permissions` |
| Visitor errors stats | stats | `manage_visitor_errors` |
| Quick actions | main | -- |
| Recent errors | main | `manage_visitor_errors` |
| Analytics overview | main | `manage_analytics` |

### Adding Custom Blocks

```ruby
# config/initializers/ruby_cms.rb (or ruby_cms_pages.rb)
Rails.application.config.to_prepare do
  RubyCms.dashboard_register(
    key: :orders_stats,
    label: "Orders",
    section: :stats,          # :stats (top row) or :main (bottom grid)
    order: 5,
    partial: "admin/dashboard/orders_stats",
    permission: :manage_orders,
    span: :single,            # :single or :double (grid width)
    data: ->(controller) {
      { count: Order.count, today: Order.where("created_at > ?", Date.today).count }
    }
  )
end
```

Then create the partial `app/views/admin/dashboard/_orders_stats.html.erb`. The `block` local contains the registration data and any computed `data`.

### Overriding Default Blocks

Re-register with the same key to override:

```ruby
RubyCms.dashboard_register(
  key: :quick_actions,
  label: "Quick actions",
  section: :main,
  partial: "admin/dashboard/my_quick_actions"  # your own partial
)
```

## Navigation and Permissions

### register_page (recommended)

One call to register a nav item and its permission:

```ruby
RubyCms.register_page(
  key: :backups,
  label: "Backups",
  path: :admin_backups_path,        # Symbol: auto-wrapped via main_app
  icon: :archive_box,               # Named icon from RubyCms::Icons
  section: :main,                   # :main (sidebar top) or :settings (sidebar bottom)
  permission: :manage_backups,      # Auto-registered as permission key
  order: 10
)
```

### nav_register (low-level)

For more control (custom visibility gates, non-standard paths):

```ruby
RubyCms.nav_register(
  key: :reports,
  label: "Reports",
  path: ->(view) { view.main_app.reports_path },
  icon: :chart_bar,
  section: "main",
  permission: :manage_reports,
  if: ->(view) { view.current_user_cms&.admin? }
)
```

### nav_group (accordion)

Define a sidebar accordion group in the same config file as your pages:

```ruby
RubyCms.nav_group(
  key: :operations,
  label: "Operations",
  icon: :folder,
  section: "main",
  order: 20,
  # Optional: the group can have its own page
  path: ->(view) { view.main_app.admin_operations_path },
  # Child pages are referenced by the keys you used in register_page/nav_register
  children: %i[backups reports]
)
```

Groups are hidden automatically when they have no visible children and no `path`.

### Path Options

| Format | Example | Behavior |
|--------|---------|----------|
| Symbol | `:admin_backups_path` | Auto-wrapped: `view.main_app.send(:admin_backups_path)` |
| Lambda | `-> (v) { v.some_path }` | Called with view context |
| String | `"/admin/backups"` | Used as-is |

### Named Icons

Use symbol keys from `RubyCms::Icons`:

```ruby
RubyCms::Icons.available
# => [:home, :pencil_square, :document_duplicate, :chart_bar, :shield_check,
#     :exclamation_triangle, :user_group, :cog_6_tooth, :archive_box, :folder,
#     :bell, :clock, :tag, :cube, :envelope, :wrench, :globe, :photograph,
#     :list_bullet, :plus_circle, :trash, :eye, :lock_closed, :currency_dollar]
```

Raw SVG strings are also accepted for custom icons.

### Permission Keys

Default keys: `manage_admin`, `manage_permissions`, `manage_content_blocks`, `manage_visitor_errors`, `manage_analytics`.

Register additional keys:

```ruby
RubyCms.register_permission_keys(:manage_orders, :manage_reports)
```

### Permission Templates

Group permission keys into reusable templates:

```ruby
RubyCms.register_permission_template(:editor,
  label: "Editor",
  keys: %w[manage_admin manage_content_blocks],
  description: "Can manage content but not users"
)

# Apply to a user:
RubyCms::Permission.apply_template!(user, :editor)
```

### cms_page Macro

In controllers that inherit from `RubyCms::Admin::BaseController`, use `cms_page` to link to a registered page. The permission is looked up from the nav registry automatically:

```ruby
class Admin::BackupsController < RubyCms::Admin::BaseController
  cms_page :backups  # permission from register_page(:backups, permission: :manage_backups)

  def index
    @backups = Backup.recent
  end
end
```

## Admin Page Generator

Scaffold a complete admin page with one command:

```bash
rails g ruby_cms:admin_page backups
```

This generates:

| File | Description |
|------|-------------|
| `app/controllers/admin/backups_controller.rb` | Controller with `cms_page :backups` |
| `app/views/admin/backups/index.html.erb` | View template |
| `config/routes.rb` | Route injection (`namespace :admin`) |
| `config/initializers/ruby_cms_pages.rb` | `register_page` call |

### Options

```bash
rails g ruby_cms:admin_page backups \
  --permission=manage_backups \
  --icon=archive_box \
  --section=settings \
  --order=15
```

| Option | Default | Description |
|--------|---------|-------------|
| `--permission` | `manage_<name>` | Permission key |
| `--icon` | `folder` | Icon from `RubyCms::Icons` |
| `--section` | `main` | `main` or `settings` |
| `--order` | `10` | Sort order in nav |

After generating, run `rails ruby_cms:seed_permissions` to create the permission row in the database.

## Settings

RubyCMS uses DB-backed settings with a registry for defaults and types:

```ruby
# Read
RubyCms::Settings.get(:analytics_default_period, default: "week")

# Write (admin UI or programmatic)
RubyCms::Settings.set(:analytics_default_period, "month")
```

### Registering Custom Settings

```ruby
RubyCms::SettingsRegistry.register(
  key: :my_custom_setting,
  type: :string,
  default: "hello",
  category: :general,
  description: "A custom setting"
)
```

Settings are managed in **Admin > Settings** with tabs per category.

## Visitor Error Tracking

Public exceptions are automatically captured when `RubyCms::VisitorErrorCapture` is included in your `ApplicationController` (added by the install generator).

View captured errors in **Admin > Visitor errors** with status codes, paths, timestamps, and resolution tracking.

## Analytics (Ahoy)

RubyCMS integrates with Ahoy for server-side page view and event tracking.

Include `RubyCms::PageTracking` in public controllers:

```ruby
class PagesController < ApplicationController
  include RubyCms::PageTracking
end
```

View analytics in **Admin > Analytics** with:
- Visit and event counts
- Popular pages
- Top visitors
- Configurable date ranges and periods

### Customization Hooks

```ruby
RubyCms.configure do |c|
  c.analytics_visit_scope = ->(scope) { scope.where.not(ip: ["127.0.0.1"]) }
  c.analytics_event_scope = ->(scope) { scope }
  c.analytics_extra_cards = lambda { |start_date:, end_date:, period:, visits_scope:, events_scope:|
    [{ title: "Custom KPI", value: visits_scope.count }]
  }
end
```

## Seeding Content Blocks from YAML

Set the translation namespace:

```ruby
RubyCms.configure do |c|
  c.content_blocks_translation_namespace = "content_blocks"
end
```

Create locale files:

```yaml
# config/locales/en.yml
en:
  content_blocks:
    hero_title: "Welcome to my site"
    footer_text: "Copyright 2026"
```

Import:

```bash
rails ruby_cms:content_blocks:import
```

Export DB content blocks back to YAML:

```bash
rails ruby_cms:content_blocks:export
```

## Configuration

All configuration happens in `config/initializers/ruby_cms.rb`:

```ruby
RubyCms.configure do |c|
  # Base controller (must provide current_user + authentication)
  c.admin_base_controller = "ApplicationController"

  # Admin layout
  c.admin_layout = "admin/admin"

  # User model class name
  c.user_class_name = "User"

  # Allow user.admin? bypass when no Permission records exist
  c.bootstrap_admin_with_role = true

  # Redirect path for unauthenticated/unauthorized users
  c.unauthorized_redirect_path = "/"

  # Visual editor
  c.preview_templates = { "home" => "pages/home" }
  c.preview_data = ->(page_key, view) { {} }

  # Content blocks
  c.content_blocks_translation_namespace = "content_blocks"
  c.image_content_types = %w[image/png image/jpeg image/gif image/webp]
  c.image_max_size = 5 * 1024 * 1024
end
```

## Rake Tasks

| Task | Description |
|------|-------------|
| `ruby_cms:seed_permissions` | Create default permission rows + settings |
| `ruby_cms:setup_admin` | Interactive first admin user setup |
| `ruby_cms:grant_manage_admin` | Grant all permissions to a user by email |
| `ruby_cms:content_blocks:export` | Export DB content blocks to YAML |
| `ruby_cms:content_blocks:import` | Import content blocks from YAML |
| `ruby_cms:content_blocks:sync` | Export + optional import |
| `ruby_cms:import_initializer_settings` | Import initializer values into DB settings |
| `ruby_cms:css:compile` | Compile admin CSS to host app |
| `ruby_cms:css:compile_gem` | Compile admin CSS within the gem |

## Development

### Setup

```bash
git clone https://github.com/jobhammer00/ruby_cms.git
cd ruby_cms
bundle install
```

### Running Tests

```bash
bundle exec rspec
```

Tests use an in-memory SQLite database via `spec/support/dummy_app.rb`. No separate dummy Rails app directory is needed.

### CSS Compilation

```bash
rails ruby_cms:css:compile_gem
```

### Faster Docker Builds (`assets:precompile`)

`assets:precompile` loads the Rails app in production mode and can be slow in Docker/Fly builds.
RubyCMS now skips non-asset runtime initializers during this phase (navigation registration,
dashboard registration, versioning hook, settings import, and permission seeding), which reduces
precompile overhead.

Recommended Docker layer order:

1. Copy `Gemfile` / `Gemfile.lock`
2. Run `bundle install`
3. Copy app source
4. Run `SECRET_KEY_BASE=DUMMY bin/rails assets:precompile`

### Architecture

```
lib/ruby_cms.rb              # Module: nav_register, register_page, permissions API
lib/ruby_cms/engine.rb        # Rails::Engine: config, initializers, rake tasks, nav registration
lib/ruby_cms/icons.rb         # Named Heroicon SVG registry
lib/ruby_cms/dashboard_blocks.rb  # Dashboard block registry
lib/ruby_cms/settings.rb      # DB-backed settings
lib/ruby_cms/settings_registry.rb  # Settings definitions and defaults
app/controllers/ruby_cms/admin/  # Admin controllers (base, dashboard, content blocks, etc.)
app/models/                   # ContentBlock, ContentBlockVersion, Permission, etc.
app/views/ruby_cms/admin/     # Admin views
app/views/layouts/ruby_cms/   # Admin layout + sidebar
app/components/               # ViewComponents (AdminPage, etc.)
app/helpers/                  # Content block, settings, dashboard helpers
```

### Key Extension Points

| What | How |
|------|-----|
| New admin page | `rails g ruby_cms:admin_page <name>` |
| New nav item | `RubyCms.register_page(...)` or `RubyCms.nav_register(...)` |
| New permission | `RubyCms.register_permission_keys(:key)` |
| New dashboard block | `RubyCms.dashboard_register(...)` |
| New setting | `RubyCms::SettingsRegistry.register(...)` |
| New icon | Pass raw SVG string to `icon:` parameter |

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
