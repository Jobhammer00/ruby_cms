# frozen_string_literal: true

class CreateRubyCmsUserPermissions < ActiveRecord::Migration[7.1]
  def change
    create_table :ruby_cms_user_permissions do |t|
      t.references :user, null: false, foreign_key: false
      t.references :permission, null: false, foreign_key: { to_table: :ruby_cms_permissions }

      t.timestamps
    end

    add_index :ruby_cms_user_permissions, %i[user_id permission_id], unique: true
  end
end
