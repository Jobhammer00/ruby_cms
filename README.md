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

**Important:** For **placeholders** (input `placeholder`, `alt`, meta tags), use `wrap: false` or `content_block_text`. The `content_block` helper normally wraps content in a `<span>` for the visual editor; that HTML must not go into placeholder attributes:

```erb
<%= text_field_tag :name, nil, placeholder: content_block("contact.name_placeholder", wrap: false, fallback: "Your name") %>
<%= text_area_tag :message, nil, placeholder: content_block("contact.message_placeholder", wrap: false, fallback: "Your message...") %>
```

Or use `content_block_text` (equivalent to `content_block(..., wrap: false)`):

```erb
<%= text_field_tag :name, nil, placeholder: content_block_text("contact.name_placeholder", fallback: "Your name") %>
```

For **lists** (badges, tags) that you need to iterate over, use `content_block_list_items`—it returns an array instead of HTML:

```erb
<% content_block_list_items("education.item.badges", fallback: item[:badges]).each do |badge| %>
  <%= tag.span badge, class: "badge" %>
<% end %>
```

Store list content as JSON (`["Ruby", "Rails"]`) or newline-separated text in the CMS.

Create and edit blocks under **Admin → Content blocks**.

### Seeding content blocks from YAML

1. In `config/initializers/ruby_cms.rb`, set the translation namespace (the install generator sets this by default):

   ```ruby
   c.content_blocks_translation_namespace = "content_blocks"
   ```

2. Add content under that key in your locale files (e.g. `config/locales/en.yml`):

   ```yaml
   en:
     content_blocks:
       hero_title: "Welcome to my site"
       about_intro: "We build things."
       footer_copyright: "© 2025"
   ```

3. Run the seed task to import into the database (creates/updates blocks, marks them published):

   ```bash
   rails ruby_cms:content_blocks:seed
   ```

   Or call it from `db/seeds.rb`:

   ```ruby
   Rake::Task["ruby_cms:content_blocks:seed"].invoke
   ```

   ENV overrides: `published=false` to import as unpublished; `create_missing=false` or `update_existing=false` to limit what is changed.

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
