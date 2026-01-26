# frozen_string_literal: true

class CreateRubyCmsPages < ActiveRecord::Migration[7.1]
  def change
    create_table :ruby_cms_pages do |t|
      t.string :key, null: false
      t.string :template_path, null: false
      t.string :title
      t.boolean :published, default: true, null: false
      t.integer :position, default: 0, null: false

      t.timestamps
    end

    add_index :ruby_cms_pages, :key, unique: true
    add_index :ruby_cms_pages, %i[published position]
  end
end
