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
  # Use "/session/new" to send to sign-in.
  # c.unauthorized_redirect_path = "/"

  # Visual editor: allowlist of page_key => template path.
  # c.preview_templates = { "home" => "pages/home", "about" => "pages/about" }

  # Preview data proc to pass instance variables.
  # c.preview_data = ->(page_key, view) { { products: Product.limit(5) } }

  # Optional hook: customize Ahoy visit scope (e.g. exclude internal traffic)
  # c.analytics_visit_scope = ->(scope) { scope.where.not(ip: ["127.0.0.1"]) }

  # Optional hook: customize Ahoy event scope
  # c.analytics_event_scope = ->(scope) { scope }

  # Optional hook: provide extra dashboard cards
  # c.analytics_extra_cards = lambda do |start_date:, end_date:, period:, visits_scope:, events_scope:|
  #   [{ title: "Custom KPI", value: visits_scope.where.not(utm_source: nil).count }]
  # end

  # -----------------------------------------------------------------------------
  # Optional bootstrap values (initializer -> DB import, once)
  #
  # On first boot/install, RubyCMS imports matching keys from config.ruby_cms into
  # ruby_cms_preferences. After that, DB settings are source of truth.
  #
  # Example bootstrap values:
  # c.analytics_default_period = "week"
  # c.analytics_max_date_range_days = 365
  # c.analytics_cache_duration_seconds = 600
  # c.analytics_max_popular_pages = 10
  # c.analytics_max_top_visitors = 10
  # c.analytics_high_volume_threshold = 1000
  # c.analytics_rapid_request_threshold = 50
  # c.pagination_min_per_page = 5
  # c.pagination_max_per_page = 200
  # c.reserved_key_prefixes = %w[admin_]
  # c.image_content_types = %w[image/png image/jpeg image/gif image/webp]
  # c.image_max_size = 5 * 1024 * 1024
  #
  # To re-run manually:
  #   rails ruby_cms:import_initializer_settings
  # -----------------------------------------------------------------------------
end
