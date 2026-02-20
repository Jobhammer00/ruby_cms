# frozen_string_literal: true

class AddRubyCmsAnalyticsFieldsToAhoyEvents < ActiveRecord::Migration[7.1]
  def change
    return unless table_exists?(:ahoy_events)

    add_column :ahoy_events, :page_name, :string unless column_exists?(:ahoy_events, :page_name)
    add_column :ahoy_events, :request_path, :string unless column_exists?(:ahoy_events, :request_path)
    add_column :ahoy_events, :ip_address, :string unless column_exists?(:ahoy_events, :ip_address)
    add_column :ahoy_events, :user_agent, :text unless column_exists?(:ahoy_events, :user_agent)
    add_column :ahoy_events, :description, :text unless column_exists?(:ahoy_events, :description)

    add_index :ahoy_events, :page_name, if_not_exists: true
    add_index :ahoy_events, :request_path, if_not_exists: true
    add_index :ahoy_events, :ip_address, if_not_exists: true
    add_index :ahoy_events, [:name, :page_name], if_not_exists: true
    add_index :ahoy_events, [:name, :request_path], if_not_exists: true
  end
end
