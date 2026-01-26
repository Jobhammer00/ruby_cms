# frozen_string_literal: true

class CreateRubyCmsPageRegions < ActiveRecord::Migration[7.1]
  def change
    create_table :ruby_cms_page_regions do |t|
      t.references :page, null: false, foreign_key: { to_table: :ruby_cms_pages }, index: true
      t.string :key, null: false
      t.integer :position, default: 0, null: false
      t.timestamps
    end

    add_index :ruby_cms_page_regions, %i[page_id key], unique: true
    add_index :ruby_cms_page_regions, %i[page_id position]
  end
end
