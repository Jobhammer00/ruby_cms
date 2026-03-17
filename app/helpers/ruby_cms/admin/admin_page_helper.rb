# frozen_string_literal: true

module RubyCms
  module Admin
    module AdminPageHelper
      def admin_page(title: nil, subtitle: nil, footer: nil, **options, &block)
        render RubyCms::Admin::AdminPage.new(
          title: title,
          subtitle: subtitle,
          footer: footer,
          **options,
          &block
        )
      end

      def admin_table_content(id: "admin_table_content", **attrs, &block)
        render RubyCms::Admin::AdminPage::AdminTableContent.new(id: id, **attrs, &block)
      end

      # Optional RubyUI-style DSL aliases. These are defined dynamically because
      # Ruby's `def AdminPage` syntax is not allowed.
      define_method("AdminPage") do |**kwargs, &block|
        admin_page(**kwargs, &block)
      end

      define_method("AdminTableContent") do |**kwargs, &block|
        admin_table_content(**kwargs, &block)
      end
    end
  end
end

