# frozen_string_literal: true

class CreateRubyCmsNavigationMenus < ActiveRecord::Migration[7.1]
  def change
    create_table :ruby_cms_navigation_menus do |t|
      t.string :key, null: false
      t.string :name, null: false
      t.integer :position, default: 0, null: false
      t.boolean :published, default: true, null: false
      t.timestamps
    end

    add_index :ruby_cms_navigation_menus, :key, unique: true
    add_index :ruby_cms_navigation_menus, %i[published position]
  end
end
