# frozen_string_literal: true

class AddRefererAndQueryToRubyCmsVisitorErrors < ActiveRecord::Migration[7.1]
  def change
    add_column :ruby_cms_visitor_errors, :referer, :string
    add_column :ruby_cms_visitor_errors, :query_string, :string
  end
end
