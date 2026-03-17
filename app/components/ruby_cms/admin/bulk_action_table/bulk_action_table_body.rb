# frozen_string_literal: true

module RubyCms
  module Admin
    module BulkActionTable
      # Table body component
      # Simple wrapper for <tbody> content
      class BulkActionTableBody < BaseComponent
        def view_template(&)
          tbody(class: "divide-y divide-gray-100", &)
        end
      end
    end
  end
end
