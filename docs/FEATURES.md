# RubyCMS — feature reference

This document lists what the engine provides. The [README](../README.md) stays a short overview and quick start; use this file (or your own wiki) for a full checklist.

## Admin areas (`/admin/...`)

| Area | Path (engine) | Notes |
|------|----------------|-------|
| Dashboard | `/admin` | Entry point after sign-in |
| Visual editor | `/admin/visual_editor` | Inline editing against configured preview templates |
| Content blocks | `/admin/content_blocks` | CRUD, locales, rich text (Action Text), bulk publish/delete |
| Permissions | `/admin/permissions` | Permission keys; bulk delete |
| Users | `/admin/users` | List/create/destroy; per-user permission assignment |
| Visitor errors | `/admin/visitor_errors` | Captured public exceptions; resolve, bulk actions |
| Analytics | `/admin/analytics` | Ahoy-based dashboard; page and IP drill-down |
| Settings | `/admin/settings` | DB-backed RubyCMS settings, nav order, reset defaults |
| Locale | `PATCH /admin/locale` | Admin UI language switch |

### Analytics extras

- **Page details**: query param flow from dashboard (`page_details`)
- **Visitor details**: IP-based drill-down (`visitor_details`)
- Reporting logic: `RubyCms::Analytics::Report` (cached aggregates)

## Public / developer integration

- **`content_block` helper** — text, rich text, images, links, lists; visual editor wrappers
- **`content_block_list_items`**, **`content_block_text`**, placeholders (`wrap: false`)
- **`RubyCms::PageTracking`** — `ahoy.track "page_view"` from host controllers
- **`RubyCms::Permittable`** on `User` — `can?` / permission checks
- **`admin_page` helper** — consistent admin layout for host-owned admin pages
- **Catch-all 404 route** (optional, from install generator) — visitor error tracking for missing pages

## Install generator (`rails g ruby_cms:install`)

Typical tasks (see generator for current behavior):

- Initializer `config/initializers/ruby_cms.rb` (session, CSP, preview templates, hooks)
- Mount engine routes
- Authentication checks / User concerns (when applicable)
- Ahoy, Action Text, Tailwind/importmap wiring as needed
- Optional catch-all route for 404s

## Rake tasks (non-exhaustive)

- `ruby_cms:seed_permissions` / `ruby_cms:import_initializer_settings`
- `ruby_cms:setup_admin` / `ruby_cms:grant_manage_admin`
- `ruby_cms:content_blocks:seed` — seed blocks from YAML/locales
- `ruby_cms:content_blocks:export` / `import` / `sync` — YAML sync
- `ruby_cms:css:compile` / `ruby_cms:css:compile_gem` — admin CSS build

## Configuration surface

Most behavior is controlled via `Rails.application.config.ruby_cms` (see initializer template) and **`RubyCms::Settings`** (DB + optional import from initializer).

## What the README does *not* deep-dive

- Every analytics metric and SQL scope
- Full list of permission keys and nav registration API
- Security / GDPR choices for Ahoy and IP storage
- Host-app-specific modules (e.g. custom admin resources) — those live in the host app

For release-level changes, see [CHANGELOG.md](../CHANGELOG.md).

## Wiki vs this repo

- **In-repo docs** (this file): versioned with the gem, good for contributors and GitHub readers.
- **GitHub Wiki**: optional for long tutorials or deployment runbooks; can duplicate or link here to avoid drift.
