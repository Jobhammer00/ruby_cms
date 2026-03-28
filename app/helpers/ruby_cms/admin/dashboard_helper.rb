# frozen_string_literal: true

module RubyCms
  module Admin
    module DashboardHelper
      # Renders a dashboard block from the registry (+ :locals from the controller).
      def render_dashboard_block(block)
        locals = block[:locals]
        locals = {} if locals.nil?
        if block[:partial].present?
          render partial: block[:partial], locals: locals
        elsif block[:render].respond_to?(:call)
          block[:render].call(self, locals)
        else
          ""
        end
      end
    end
  end
end
