# frozen_string_literal: true

# RubyCMS configuration

# -----------------------------------------------------------------------------
# Session / cookie hardening (recommended for /admin)
# Apply in config/initializers/session_store.rb or your session config:
#
#   Rails.application.config.session_store :cookie_store,
#     key: "_session",
#     httponly: true,
#     same_site: :lax,        # or :strict
#     secure: Rails.env.production?,
#     expire_after: 2.weeks
#
# In your auth flow: rotate session on sign-in (e.g. Session.find_by(...)&.destroy
# before creating a new one). Use safe return-to: validate redirect paths to same
# origin or allowlist; avoid open redirects.
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# CSP (Content Security Policy): set sensible defaults; document overrides.
# Example in config/initializers/content_security_policy.rb:
#
#   Rails.application.config.content_security_policy do |p|
#     p.default_src :self; p.script_src :self; p.style_src :self, :unsafe_inline
#   end
# -----------------------------------------------------------------------------

RubyCms.configure do |c|
  # Controller from which all /admin controllers inherit.
  # Must provide current_user and run require_authentication.
  # c.admin_base_controller = "ApplicationController"

  # User model class name for permissions. Change if your app uses a different name.
  # c.user_class_name = "User"

  # When no Permission records exist, allow user.admin? to access /admin (bootstrap).
  # Set to false to require permissions from the start.
  # c.bootstrap_admin_with_role = true

  # Redirect path when unauthenticated or not permitted (default: "/").
  # Use "/session/new" to send to sign-in, or main_app.root_path in a proc if you define root.
  # c.unauthorized_redirect_path = "/"

  # Content blocks: key prefixes that cannot be used (default: ["admin_"]).
  # c.reserved_key_prefixes = %w[admin_]

  # Content blocks: translation namespace for seed-from-YAML. When set (e.g. "content_blocks"),
  # put content under that key in config/locales/<locale>.yml, then run:
  #   rails ruby_cms:content_blocks:seed
  # Or from db/seeds.rb: Rake::Task["ruby_cms:content_blocks:seed"].invoke
  # Example in config/locales/en.yml:
  #   en:
  #     content_blocks:
  #       hero_title: "Welcome"
  #       about_intro: "About us..."
  # c.content_blocks_translation_namespace = "content_blocks"

  # Visual editor: allowlist of page_key => template path;
  # Page records are merged with this config. Example: "home" => "pages/home"
  # c.preview_templates = { "home" => "pages/home", "about" => "pages/about" }

  # Preview data proc to pass instance variables to the preview template. Example:
  # c.preview_data = ->(page_key, view) { { products: Product.limit(5) } }

  # App Integration: Link App routes and settings
  # Register app routes that can be linked from CMS navigation:
  #   RubyCms.register_app_route(
  #     key: "products",
  #     route_name: "products_path",
  #     label: "Products",
  #     description: "View all products"
  #   )
  #
  # Register app settings to load into CMS context:
  #   RubyCms.register_app_setting(
  #     key: "current_tenant",
  #     loader: ->(view) { view.current_tenant }
  #   )
  #
  # In views, use: cms_app_setting("current_tenant")
end
