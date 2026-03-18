# frozen_string_literal: true

class CreateRubyCmsVisitorErrors < ActiveRecord::Migration[7.1]
  def change
    create_table :ruby_cms_visitor_errors do |t|
      t.string :error_class, null: false
      t.text :error_message, null: false
      t.string :request_path, null: false
      t.string :request_method
      t.string :ip_address
      t.text :user_agent
      t.text :backtrace
      t.text :request_params
      t.string :session_id
      t.boolean :resolved, default: false, null: false

      t.timestamps
    end

    add_index :ruby_cms_visitor_errors, :created_at
    add_index :ruby_cms_visitor_errors, :request_path
    add_index :ruby_cms_visitor_errors, :resolved
  end
end
