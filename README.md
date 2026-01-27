# RubyCMS

Reusable Rails engine: admin-only auth, permissions, admin shell, content blocks, and visual editor.

**Vision:** The CMS manages content (content blocks, visual editor); the programmer builds the SaaS product (auth, billing, dashboards, etc.). You define pages and templates in your app; you edit content using the visual editor.

## Features

- **Visual Editor** - Inline editing of content blocks
- **Content Blocks** - Reusable content snippets with rich text support
- **Pages** - Display pages with template mode (pages can be created programmatically)
- **Permissions** - Fine-grained permission system
- **Users** - User management with permission assignments

## Documentation

- **[Installation](#installation)** - Get started with RubyCMS
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

### 4. Add the ruby_cms gem

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

### 5. Install RubyCMS

```bash
rails g ruby_cms:install
```

This creates `config/initializers/ruby_cms.rb`, mounts the engine, and injects `include RubyCms::Permittable` into `User`. If `app/models/user.rb` is missing, it will run `rails g authentication` and `bundle install` for you (Rails 8+); you can then skip step 2 and run `rails db:migrate` after this.

### 6. Migrate and seed

```bash
rails db:migrate
rails ruby_cms:seed_permissions
```

### 7. Resolve route conflicts

If the app already has `/admin` routes, remove or change them so RubyCMS can use `/admin`. The install adds `mount RubyCms::Engine => "/"`; keep it after your main routes (e.g. `root`, `resources`) so it doesn’t override them.
### 8. Configure JavaScript/Stimulus controllers

RubyCMS uses Stimulus controllers for interactive features. The engine automatically registers controllers when `window.Stimulus` is available.

**For Rails 7+ with importmap**, ensure your `app/javascript/controllers/application.js` exports the Stimulus application to `window`:

```javascript
import { Application } from "@hotwired/stimulus"

const application = Application.start()
application.debug = false
window.Stimulus = application  // Required for RubyCMS controllers

export { application }
```

Then in `app/javascript/controllers/index.js`, import the ruby_cms controllers:

```javascript
import { application } from "controllers/application"
import { registerRubyCmsControllers } from "ruby_cms"

registerRubyCmsControllers(application)

// ... your other controller imports
```

This ensures RubyCMS Stimulus controllers (`ruby-cms--mobile-menu`, `ruby-cms--bulk-action-table`, etc.) are properly registered.
### 9. Create an admin user and open /admin

**Recommended:** run the interactive Thor CLI to pick or create the first admin and grant full permissions:

```bash
rails ruby_cms:setup_admin
```

You can select an existing user, enter another email, or create a new user. The CLI grants `manage_admin`, `manage_permissions`, and `manage_content_blocks`.

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

Pages can be created programmatically (via console, seeds, or migrations). Each page maps a `key` (e.g. `home`) to a view `template_path` (e.g. `pages/home`). You implement that template in your app (e.g. `app/views/pages/home.html.erb`).

- **Public URL:** `GET /p/:key` renders the page (published only). Example: `/p/home` → `pages/home`.
- **Visual editor:** Pages are loaded from the database and merged with `config.ruby_cms.preview_templates` for the page selector and preview. Configure pages via `c.preview_templates = { "home" => "pages/home" }` in the initializer.

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

1. **Preview templates** come from page records in the database and/or `config.ruby_cms.preview_templates` in `config/initializers/ruby_cms.rb`. Page records override config for the same key.

   ```ruby
   c.preview_templates = { "home" => "pages/home", "about" => "pages/about" }
   c.preview_data = ->(page_key, view) { { products: Product.limit(5) } }
   ```

2. Create the view templates (e.g. `app/views/pages/home.html.erb`) and use the `content_block("key")` helper for editable regions. Wrap editable elements in `<div class="ruby_cms-content-block" data-content-key="...">`.

3. Open **Admin → Visual editor**, pick a page, and click any content block in the preview to edit in the modal.

4. **postMessage**: The preview iframe and parent communicate via postMessage for content block editing and updates.

---

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt.

To install this gem onto your local machine, run `bundle exec rake install`.

## Contributing

Bug reports and pull requests are welcome on GitHub.
