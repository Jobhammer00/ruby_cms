# frozen_string_literal: true

module RubyCms
  module Admin
    module BulkActionTable
      # Table body component
      # Simple wrapper for <tbody> content
      class BulkActionTableBody < BaseComponent
        def view_template(&)
          tbody(class: "[&_tr:last-child]:border-0 [&_td]:text-sm", &)
        end
      end
    end
  end
end
