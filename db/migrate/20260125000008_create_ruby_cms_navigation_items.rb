# frozen_string_literal: true

class CreateRubyCmsNavigationItems < ActiveRecord::Migration[7.1]
  def json_type
    connection.adapter_name.to_s.downcase.include?("postgres") ? :jsonb : :json
  end

  def change
    create_table :ruby_cms_navigation_items do |t|
      t.references :navigation_menu, null: false, foreign_key: { to_table: :ruby_cms_navigation_menus }, index: true
      t.string :label, null: false
      t.string :url
      t.string :page_key
      t.string :route_name
      t.public_send(json_type, :route_params, default: {})
      t.string :link_type, default: "url", null: false # url, page, route
      t.integer :position, default: 0, null: false
      t.references :parent, foreign_key: { to_table: :ruby_cms_navigation_items }, index: true
      t.boolean :published, default: true, null: false
      t.timestamps
    end

    add_index :ruby_cms_navigation_items, %i[navigation_menu_id position]
    add_index :ruby_cms_navigation_items, :page_key
  end
end
