# frozen_string_literal: true

class AddRenderModesToRubyCmsPages < ActiveRecord::Migration[7.1]
  def change
    add_column :ruby_cms_pages, :render_mode, :string, default: "template", null: false
    add_column :ruby_cms_pages, :body_html, :text
    add_column :ruby_cms_pages, :layout, :string
    add_column :ruby_cms_pages, :compiled_html, :text
    add_column :ruby_cms_pages, :compiled_at, :datetime

    # Make template_path nullable (only required for template mode)
    change_column_null :ruby_cms_pages, :template_path, true

    # Set render_mode to 'builder' for pages that have regions (already using builder)
    execute <<-SQL
      UPDATE ruby_cms_pages
      SET render_mode = 'builder'
      WHERE id IN (
        SELECT DISTINCT page_id
        FROM ruby_cms_page_regions
      )
    SQL

    add_index :ruby_cms_pages, :render_mode
  end
end
