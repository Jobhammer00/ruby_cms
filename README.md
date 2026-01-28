# RubyCMS

Reusable Rails engine: admin-only auth, permissions, admin shell, content blocks, and visual editor.

**Vision:** The CMS manages content (content blocks, visual editor); the programmer builds the SaaS product (auth, billing, dashboards, etc.). You define pages and templates in your app; you edit content using the visual editor.

## Features

- **Visual Editor** - Inline editing of content blocks
- **Content Blocks** - Reusable content snippets with rich text support
- **Permissions** - Fine-grained permission system
- **Users** - User management with permission assignments

## Documentation

- **[Installation](#installation)** - Get started with RubyCMS
- **[Usage](#usage)** - Basic usage examples

## Installation {#installation}

### 1. Create a Rails app (or use an existing one)

```bash
rails new my_cms_app -d sqlite3
cd my_cms_app
```

### 2. Install RubyCMS

```bash
rails g ruby_cms:install
```

This generator:

- configures RubyCMS (`config/initializers/ruby_cms.rb`) and mounts the engine,
- ensures authentication is present (generates `User`, `Session`, and `Authentication` on Rails 8+ apps that need it),
- installs Action Text / Active Storage when missing and runs the required `db:migrate`,
- creates the RubyCMS tables and seeds permissions,
- guides you through picking or creating the first admin user and granting CMS permissions.

### 3. Resolve route conflicts

If the app already has `/admin` routes, remove or change them so RubyCMS can use `/admin`. The install adds `mount RubyCms::Engine => "/"`; keep it after your main routes (e.g. `root`, `resources`) so it doesn’t override them.


## Usage

### Content blocks

In any view:

```erb
<%= content_block("hero_title", default: "Welcome") %>
<%= content_block("footer", cache: true) %>
```

Create and edit blocks under **Admin → Content blocks**.

### Visual editor

1. **Preview templates** come from `config.ruby_cms.preview_templates` in `config/initializers/ruby_cms.rb`.

   ```ruby
   c.preview_templates = { "home" => "pages/home", "about" => "pages/about" }
   c.preview_data = ->(page_key, view) { { products: Product.limit(5) } }
   ```

2. Create the view templates (e.g. `app/views/pages/home.html.erb`) and use the `content_block("key")` helper for editable regions. Wrap editable elements in `<div class="ruby_cms-content-block" data-content-key="...">`.

3. Open **Admin → Visual editor**, pick a page, and click any content block in the preview to edit in the modal.

4. **postMessage**: The preview iframe and parent communicate via postMessage for content block editing and updates.

---
