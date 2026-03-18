# frozen_string_literal: true

module RubyCms
  module Admin
    class AdminPage
      # Optional wrapper for pages that want a consistent Turbo Frame target
      # for table/content updates (pagination, filters, search, etc).
      #
      # Default ID matches RubyCMS convention: "admin_table_content".
      class AdminTableContent < BaseComponent
        def initialize(id: "admin_table_content", **attrs)
          super()
          @id = id
          @attrs = attrs
        end

        def view_template(&)
          turbo_frame_tag(@id, **default_attrs.merge(@attrs), &)
        end

        private

        def default_attrs
          {
            class: "flex-1 flex flex-col min-h-0",
            data: { turbo_action: "advance" }
          }
        end
      end
    end
  end
end
