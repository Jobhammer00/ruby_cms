# frozen_string_literal: true

class CreateRubyCmsPageNodes < ActiveRecord::Migration[7.1]
  def json_type
    connection.adapter_name.to_s.downcase.include?("postgres") ? :jsonb : :json
  end

  def change
    create_table :ruby_cms_page_nodes do |t|
      t.references :page_region, null: false, foreign_key: { to_table: :ruby_cms_page_regions }, index: true
      t.string :component_key, null: false
      t.public_send(json_type, :props, default: {}, null: false)
      t.integer :position, default: 0, null: false
      t.references :parent, foreign_key: { to_table: :ruby_cms_page_nodes }, index: true
      t.timestamps
    end

    add_index :ruby_cms_page_nodes, %i[page_region_id position]
    add_index :ruby_cms_page_nodes, :component_key
  end
end
