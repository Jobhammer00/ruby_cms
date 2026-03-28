# frozen_string_literal: true

class CreateContentBlockVersions < ActiveRecord::Migration[7.1]
  def change
    create_table :content_block_versions do |t|
      t.references :content_block, null: false, foreign_key: true, index: true
      t.references :user, null: true, foreign_key: true
      t.integer :version_number, null: false
      t.string :title, null: false
      t.text :content
      t.text :rich_content_html
      t.string :content_type, null: false
      t.boolean :published, null: false, default: true
      t.string :event, null: false, default: "update"
      t.jsonb :metadata, default: {}
      t.datetime :created_at, null: false
    end

    add_index :content_block_versions, %i[content_block_id version_number],
              unique: true, name: "idx_cb_versions_on_block_and_number"
  end
end
