# frozen_string_literal: true

class AddDraftToRubyCmsPages < ActiveRecord::Migration[7.1]
  def change
    add_column :ruby_cms_pages, :draft, :boolean, default: false, null: false
    add_index :ruby_cms_pages, :draft
  end
end
