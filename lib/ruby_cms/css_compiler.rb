# frozen_string_literal: true

require "pathname"

module RubyCms
  # Compiles admin.css from component files (no Rails required).
  # Used by Engine.compile_admin_css and rake tasks.
  module CssCompiler
    # Core shared styles MUST be loaded first, then specific components
    COMPONENTS = %w[
      shared
      layout sidebar header cards dashboard buttons forms alerts
      flash_toast modals content_blocks visitor_errors settings
      bulk_action_table bulk_action_table_bar bulk_action_table_delete
      visual_editor visual_editor_header visual_editor_preview visual_editor_modal
      visual_editor_edit_mode
      mobile scrollbar utilities
    ].freeze

    def self.compile(gem_root, dest_path)
      src_dir = Pathname(gem_root).join("app/assets/stylesheets/ruby_cms")
      components_dir = src_dir.join("components")
      header = <<~CSS

      CSS
      content = COMPONENTS.filter_map do |name|
        file = components_dir.join("#{name}.css")
        next nil unless file.exist?

        "/* ===== Component: #{name} ===== */\n#{File.read(file)}\n"
      end.compact.join("\n")
      File.write(dest_path, header + content)
    end
  end
end
