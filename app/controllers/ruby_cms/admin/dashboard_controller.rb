# frozen_string_literal: true

module RubyCms
  module Admin
    class DashboardController < BaseController
      def index
        @content_blocks_count = RubyCms::ContentBlock.count
        @content_blocks_published_count = RubyCms::ContentBlock.published.count
      end
    end
  end
end
