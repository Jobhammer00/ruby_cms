# RubyCMS

Reusable Rails engine: admin-only auth, permissions, admin shell, **pages**, content blocks, visual editor, and **page builder**.

**Vision:** The CMS builds the site (pages, content, visual editor, page builder); the programmer builds the SaaS product (auth, billing, dashboards, etc.). You define pages and templates in the CMS; you implement the view files and app logic in the host.

## Features

- **Page Builder** - Drag-and-drop interface for building pages with components
- **Visual Editor** - Inline editing of content blocks
- **Content Blocks** - Reusable content snippets with rich text support
- **Pages** - Manage pages with multiple render modes (builder, HTML, template)
- **Navigation** - Menu and navigation item management
- **Permissions** - Fine-grained permission system
- **RubyUI Integration** - Automatically use RubyUI components in the page builder

## Documentation

- **[Installation](#installation)** - Get started with RubyCMS
- **[Page Builder](docs/Page%20Builder.md)** - Complete guide to the page builder
- **[Usage](#usage)** - Basic usage examples

See [PLAN.md](PLAN.md) for the roadmap.

## Installation {#installation}

### 1. Create a Rails app (or use an existing one)

```bash
rails new my_cms_app -d sqlite3
cd my_cms_app
```

### 2. Add authentication (required)

The host must have `User`, `Session`, and an `Authentication` concern with `require_authentication` and `current_user`. On **Rails 8** you can run:

```bash
rails g authentication
rails db:migrate
```

The `rails g ruby_cms:install` step (below) will run `rails g authentication` for you when `app/models/user.rb` is missing (Rails 8+). If it does, you can skip this step and run `rails db:migrate` after the install.

### 3. Add Action Text and Active Storage (for content blocks)

```bash
rails action_text:install
rails db:migrate
```

(Active Storage is usually already present in a new Rails app.)

### 4. (Optional) Add RailsUI for Page Builder components

To use RubyUI components in the page builder:

```ruby
# Gemfile
gem "rails_ui", ">= 1.0"
```

Then:

```bash
bundle install
```

Create RubyUI components in `app/components/ruby_ui/` - they'll be automatically discovered and available in the page builder. See [Page Builder documentation](docs/Page%20Builder.md) for details.

### 5. Add the ruby_cms gem

**From a local path** (e.g. when developing the gem):

```ruby
# Gemfile
gem "ruby_cms", path: "../gems/ruby_cms"   # adjust to your gems/ruby_cms path
```

**From RubyGems** (after release):

```ruby
gem "ruby_cms"
```

Then:

```bash
bundle install
```

### 6. Install RubyCMS

```bash
rails g ruby_cms:install
```

This creates `config/initializers/ruby_cms.rb`, mounts the engine, and injects `include RubyCms::Permittable` into `User`. If `app/models/user.rb` is missing, it will run `rails g authentication` and `bundle install` for you (Rails 8+); you can then skip step 2 and run `rails db:migrate` after this.

### 7. Migrate and seed

```bash
rails db:migrate
rails ruby_cms:seed_permissions
```

### 8. Resolve route conflicts

If the app already has `/admin` routes, remove or change them so RubyCMS can use `/admin`. The install adds `mount RubyCms::Engine => "/"`; keep it after your main routes (e.g. `root`, `resources`) so it doesn’t override them.

### 9. Create an admin user and open /admin

**Recommended:** run the interactive Thor CLI to pick or create the first admin and grant full permissions:

```bash
rails ruby_cms:setup_admin
```

You can select an existing user, enter another email, or create a new user. The CLI grants `manage_admin`, `manage_permissions`, `manage_content_blocks`, `manage_pages`, and `publish_pages`.

Alternatively:

- **Non-interactive:** `rails ruby_cms:grant_manage_admin email=you@example.com` (grants `manage_admin` only).
- **Bootstrap (no Permission records yet):** add an `admin` column to `User`, set `admin: true`, and use `config.ruby_cms.bootstrap_admin_with_role`; or assign permissions under **Admin → Users → Permissions** once you have access.

You can also run the Thor CLI as a standalone command from your app root: `bundle exec ruby_cms` or `bundle exec ruby_cms setup_admin`.

```bash
rails server
# Open http://localhost:3000/admin (signed in as the admin you configured)
```

---

## Testing the gem from the repo

From the gem directory:

```bash
cd /path/to/gems/ruby_cms
bundle install
bin/console   # try RubyCms, RubyCms::Permission, etc.
```

To run inside a real app (e.g. notesk or a new app):

1. In the app `Gemfile`: `gem "ruby_cms", path: "../gems/ruby_cms"` (path is relative to the app root; adjust if your layout differs).
2. `bundle install`
3. Follow steps 5–8 above.

**Quick test with notesk** (or any app that already has `rails g authentication`–style User, Session, `Authentication`): add the gem, `bundle install`, `rails g ruby_cms:install`, `rails db:migrate`, `rails ruby_cms:seed_permissions`. Remove or rename existing `/admin` routes if they conflict, then visit `/admin`.

---

## Usage

### Pages

Create pages under **Admin → Pages** (key, template path, title, published, position). Each page maps a `key` (e.g. `home`) to a view `template_path` (e.g. `pages/home`). You implement that template in your app (e.g. `app/views/pages/home.html.erb`).

- **Public URL:** `GET /p/:key` renders the page (published only). Example: `/p/home` → `pages/home`.
- **Visual editor:** Page records are merged with `config.ruby_cms.preview_templates` for the page selector and preview. You can use **either** Admin → Pages **or** `c.preview_templates = { "home" => "pages/home" }` in the initializer.

To serve the home page at `/`, add to your routes (before the engine mount):

```ruby
root to: "ruby_cms/public/pages#show", defaults: { key: "home" }
```

### Content blocks

In any view:

```erb
<%= content_block("hero_title", default: "Welcome") %>
<%= content_block("footer", cache: true) %>
```

Create and edit blocks under **Admin → Content blocks**.

### Visual editor

1. **Preview templates** come from **Admin → Pages** and/or `config.ruby_cms.preview_templates` in `config/initializers/ruby_cms.rb`. Page records override config for the same key.

   ```ruby
   c.preview_templates = { "home" => "pages/home", "about" => "pages/about" }
   c.preview_data = ->(page_key, view) { { products: Product.limit(5) } }
   ```

2. Create the view templates (e.g. `app/views/pages/home.html.erb`) and use the `content_block("key")` helper for editable regions. Wrap editable elements in `<div class="content-block" data-block-id="..." data-content-key="...">`.

3. Open **Admin → Visual editor**, pick a page, and click any `.content-block` in the iframe to edit in the modal. Use bulk actions to publish/unpublish blocks.

4. **postMessage**: The preview iframe and parent check `event.origin` and a per-load `nonce` for `ruby_cms:content_block:click` and `ruby_cms:preview:reload`.

### Page Builder

The Page Builder provides a drag-and-drop interface for building pages. See the [Page Builder documentation](docs/Page%20Builder.md) for complete details.

**Quick start:**

1. Create a page in **Admin → Pages** with render mode "builder"
2. Open **Admin → Page Builder** and select your page
3. Drag components from the palette to build your page
4. Click components to edit their properties
5. Save your changes

**RubyUI Components:**

If you have `rails_ui` installed, the following components are automatically available:

- Button
- Text (Typography)
- Heading (Typography)
- DropdownMenu
- Sidebar (if available)

Components are automatically discovered from `app/components/ruby_ui/` in your host application. No configuration needed!

---

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt.

To install this gem onto your local machine, run `bundle exec rake install`.

## Contributing

Bug reports and pull requests are welcome on GitHub.
