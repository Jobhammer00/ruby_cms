# frozen_string_literal: true

class CreateRubyCmsContentBlocks < ActiveRecord::Migration[7.1]
  def change # rubocop:disable Metrics/MethodLength
    create_table :ruby_cms_content_blocks do |t|
      t.string :key, null: false
      t.string :title
      t.text :content
      t.string :content_type, default: "text", null: false
      t.boolean :published, default: false, null: false
      t.references :updated_by, null: true, foreign_key: false

      t.timestamps
    end

    add_index :ruby_cms_content_blocks, :key, unique: true
    add_index :ruby_cms_content_blocks, %i[published content_type]
  end
end
