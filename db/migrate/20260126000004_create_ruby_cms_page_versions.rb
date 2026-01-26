# frozen_string_literal: true

class CreateRubyCmsPageVersions < ActiveRecord::Migration[7.1]
  def json_type
    connection.adapter_name.to_s.downcase.include?("postgres") ? :jsonb : :json
  end

  def change
    create_table :ruby_cms_page_versions do |t|
      t.references :page, null: false, foreign_key: { to_table: :ruby_cms_pages }, index: true
      t.string :title
      t.text :body_html
      t.string :layout
      t.string :render_mode
      t.public_send(json_type, :region_snapshot, default: {}) # Snapshot of regions/nodes structure
      t.integer :version_number, null: false
      t.references :created_by, null: true, foreign_key: false, index: true
      t.text :notes
      t.timestamps
    end

    add_index :ruby_cms_page_versions, [:page_id, :version_number], unique: true
    add_index :ruby_cms_page_versions, :created_at
  end
end
