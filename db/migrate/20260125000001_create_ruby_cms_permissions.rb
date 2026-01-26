# frozen_string_literal: true

class CreateRubyCmsPermissions < ActiveRecord::Migration[7.1]
  def change
    create_table :ruby_cms_permissions do |t|
      t.string :key, null: false
      t.string :name

      t.timestamps
    end

    add_index :ruby_cms_permissions, :key, unique: true
  end
end
