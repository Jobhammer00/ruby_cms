# frozen_string_literal: true

class AddDepthToRubyCmsPageNodes < ActiveRecord::Migration[7.1]
  def change
    add_column :ruby_cms_page_nodes, :depth, :integer, default: 0, null: false
    add_index :ruby_cms_page_nodes, :depth
    
    # Set initial depth values based on parent relationships
    reversible do |dir|
      dir.up do
        execute <<-SQL
          UPDATE ruby_cms_page_nodes
          SET depth = (
            WITH RECURSIVE depth_calc AS (
              SELECT id, parent_id, 0 AS depth
              FROM ruby_cms_page_nodes
              WHERE parent_id IS NULL
              
              UNION ALL
              
              SELECT pn.id, pn.parent_id, dc.depth + 1
              FROM ruby_cms_page_nodes pn
              INNER JOIN depth_calc dc ON pn.parent_id = dc.id
            )
            SELECT depth FROM depth_calc WHERE depth_calc.id = ruby_cms_page_nodes.id
          )
        SQL
      end
    end
  end
end
