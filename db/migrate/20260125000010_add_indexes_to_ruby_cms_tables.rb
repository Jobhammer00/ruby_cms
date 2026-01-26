# frozen_string_literal: true

class AddIndexesToRubyCmsTables < ActiveRecord::Migration[7.1]
  def change
    unless index_exists?(:ruby_cms_content_blocks, :updated_by_id)
      add_index :ruby_cms_content_blocks, :updated_by_id
    end
    # Note: parent_id index already exists on navigation_items (added in create migration)
  end
end
