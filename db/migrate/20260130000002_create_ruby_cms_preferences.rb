# frozen_string_literal: true

class CreateRubyCmsPreferences < ActiveRecord::Migration[7.1]
  def change
    create_table :ruby_cms_preferences do |t|
      t.string :key, null: false
      t.text :value
      t.string :value_type, default: "string", null: false
      t.text :description

      t.timestamps
    end

    add_index :ruby_cms_preferences, :key, unique: true
  end
end
