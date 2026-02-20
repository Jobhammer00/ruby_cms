# frozen_string_literal: true

# Importmap pins for the RubyCms engine.
#
# This file is loaded by the host application via:
#   app.config.importmap.paths << RubyCms::Engine.root.join("config/importmap.rb")
#
# Ensure the engine's app/javascript is in config.assets.paths (done by the engine).

# Pin the main RubyCms controllers index for easy registration
pin "ruby_cms", to: "controllers/ruby_cms/index.js", preload: true

# Alias pins for ruby_cms/ namespace (used by index.js imports)
pin "ruby_cms/visual_editor_controller", to: "controllers/ruby_cms/visual_editor_controller.js"
pin "ruby_cms/mobile_menu_controller", to: "controllers/ruby_cms/mobile_menu_controller.js"
pin "ruby_cms/flash_messages_controller", to: "controllers/ruby_cms/flash_messages_controller.js"
pin "ruby_cms/bulk_action_table_controller",
    to: "controllers/ruby_cms/bulk_action_table_controller.js"
pin "ruby_cms/toggle_controller", to: "controllers/ruby_cms/toggle_controller.js"
pin "ruby_cms/locale_tabs_controller", to: "controllers/ruby_cms/locale_tabs_controller.js"
pin "ruby_cms/visual_editor_header_controller",
    to: "controllers/ruby_cms/visual_editor_header_controller.js"
pin "ruby_cms/clickable_row_controller", to: "controllers/ruby_cms/clickable_row_controller.js"
pin "ruby_cms/auto_save_preference_controller",
    to: "controllers/ruby_cms/auto_save_preference_controller.js"
pin "ruby_cms/nav_order_sortable_controller",
    to: "controllers/ruby_cms/nav_order_sortable_controller.js"
pin "ruby_cms/page_preview_controller", to: "controllers/ruby_cms/page_preview_controller.js"
