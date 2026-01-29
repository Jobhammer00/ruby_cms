# frozen_string_literal: true

module RubyCms
  module Admin
    # Base component class for admin components
    # Inherits from RubyUI::Base if available, otherwise Phlex::HTML
    class BaseComponent < (defined?(RubyUI) && RubyUI.const_defined?(:Base) ? RubyUI::Base : Phlex::HTML)
      # Include Rails helpers if Phlex::HTML is used directly
      if defined?(Phlex::Rails::Helpers)
        if defined?(Phlex::Rails::Helpers::FormAuthenticityToken)
          include Phlex::Rails::Helpers::FormAuthenticityToken
        end
        if defined?(Phlex::Rails::Helpers::TurboFrameTag)
          include Phlex::Rails::Helpers::TurboFrameTag
        end
        include Phlex::Rails::Helpers::Sanitize if defined?(Phlex::Rails::Helpers::Sanitize)
        include Phlex::Rails::Helpers::LinkTo if defined?(Phlex::Rails::Helpers::LinkTo)
        include Phlex::Rails::Helpers::ButtonTo if defined?(Phlex::Rails::Helpers::ButtonTo)
        include Phlex::Rails::Helpers::FormWith if defined?(Phlex::Rails::Helpers::FormWith)
      end

      # Helper method to build CSS classes from hash or array
      def build_classes(*classes)
        classes.flatten.compact.join(" ")
      end

      # Helper method to merge data attributes
      def merge_data_attributes(base_data, additional_data)
        base_data.merge(additional_data || {})
      end

      # Helper method to conditionally add attributes
      def conditional_attributes(condition, attributes)
        condition ? attributes : {}
      end

      # Access Rails helpers (works in Phlex and RubyUI contexts)
      def helpers
        @helpers ||=
          if respond_to?(:view_context)
            view_context
          elsif defined?(Phlex::Rails::ViewContext)
            Phlex::Rails::ViewContext.current
          elsif defined?(Phlex::HTML) && respond_to?(:call)
            Thread.current[:phlex_view_context] || raise("View context not available")
          else
            raise("View context not available. Ensure component is rendered from a Rails view.")
          end
      end

      # Get form authenticity token
      def form_authenticity_token
        return helpers.form_authenticity_token if token_from_helpers?
        return super if respond_to?(:form_authenticity_token, true)
        return token_from_controller if token_from_controller?

        ""
      end

      def token_from_helpers?
        respond_to?(:helpers) && helpers.respond_to?(:form_authenticity_token)
      end

      def token_from_controller?
        defined?(ActionController::Base) && respond_to?(:controller)
      end

      def token_from_controller
        controller&.form_authenticity_token || ""
      end

      # Access controller if available
      def controller
        @controller ||= if respond_to?(:helpers) && helpers.respond_to?(:controller)
                          helpers.controller
                        elsif defined?(ActionController::Base)
                          Thread.current[:phlex_controller]
                        end
      end
    end
  end
end
