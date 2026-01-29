# frozen_string_literal: true

# DHH-style concern for publish/unpublish behavior.
# Extracts publishing logic to a reusable, self-contained module.
#
# @example
#   class ContentBlock < ApplicationRecord
#     include ContentBlock::Publishable
#   end
#
#   block.publish(user: Current.user)
#   block.unpublish(user: Current.user)
#   ContentBlock.published
#   ContentBlock.unpublished
module ContentBlock
  module Publishable
    extend ActiveSupport::Concern

    included do
      scope :published, -> { where(published: true) }
      scope :unpublished, -> { where(published: false) }
    end

    # Publish the content block.
    # @param user [User, nil] The user performing the action
    # @return [Boolean] True if successfully published
    def publish(user: nil)
      transaction do
        self.updated_by = user if user && respond_to?(:updated_by=)
        update!(published: true)
      end
      true
    rescue ActiveRecord::RecordInvalid
      false
    end

    # Unpublish the content block.
    # @param user [User, nil] The user performing the action
    # @return [Boolean] True if successfully unpublished
    def unpublish(user: nil)
      transaction do
        self.updated_by = user if user && respond_to?(:updated_by=)
        update!(published: false)
      end
      true
    rescue ActiveRecord::RecordInvalid
      false
    end

    # Check if content block is currently published.
    # @return [Boolean]
    def published?
      published == true
    end
  end
end
