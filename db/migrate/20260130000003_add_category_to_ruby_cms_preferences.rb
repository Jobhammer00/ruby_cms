# frozen_string_literal: true

class AddCategoryToRubyCmsPreferences < ActiveRecord::Migration[7.1]
  def change
    add_column :ruby_cms_preferences, :category, :string, default: "general"
    add_index :ruby_cms_preferences, :category
  end
end
