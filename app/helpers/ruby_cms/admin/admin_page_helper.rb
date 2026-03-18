# frozen_string_literal: true

module RubyCms
  module Admin
    module AdminPageHelper
      def admin_page(title: nil, subtitle: nil, footer: nil, **, &)
        render RubyCms::Admin::AdminPage.new(
          title:,
          subtitle:,
          footer:,
          **,
          &
        )
      end

      def admin_table_content(id: "admin_table_content", **attrs, &)
        render RubyCms::Admin::AdminPage::AdminTableContent.new(id:, **attrs, &)
      end
    end
  end
end
