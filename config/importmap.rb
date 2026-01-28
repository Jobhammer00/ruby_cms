# frozen_string_literal: true

# Importmap pins for the RubyCms engine.
#
# This file is loaded by the host application via:
#   app.config.importmap.paths << RubyCms::Engine.root.join("config/importmap.rb")

# Pin the main RubyCms controllers index for easy registration
pin "ruby_cms", to: "controllers/ruby_cms/index.js", preload: true

# Pin individual controllers (these paths match the file structure under app/javascript/)
pin "ruby_cms/visual_editor_controller", to: "controllers/ruby_cms/visual_editor_controller.js"
pin "ruby_cms/mobile_menu_controller", to: "controllers/ruby_cms/mobile_menu_controller.js"
pin "ruby_cms/flash_messages_controller", to: "controllers/ruby_cms/flash_messages_controller.js"
pin "ruby_cms/bulk_action_table_controller",
    to: "controllers/ruby_cms/bulk_action_table_controller.js"
pin "ruby_cms/toggle_controller", to: "controllers/ruby_cms/toggle_controller.js"
pin "ruby_cms/visual_editor_header_controller",
    to: "controllers/ruby_cms/visual_editor_header_controller.js"
