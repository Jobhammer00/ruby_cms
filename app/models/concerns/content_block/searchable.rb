# frozen_string_literal: true

# DHH-style concern for search behavior.
# Extracts search and filtering logic to a reusable module.
#
# @example
#   ContentBlock.search_by_term("welcome")
module ContentBlock
  module Searchable
    extend ActiveSupport::Concern

    included do
      # Search content blocks by key or title.
      # @param term [String] The search term
      # @return [ActiveRecord::Relation]
      scope :search_by_term, lambda {|term|
        return all if term.blank?

        search_pattern = "%#{term.to_s.downcase}%"
        where("LOWER(key) LIKE ? OR LOWER(title) LIKE ?", search_pattern, search_pattern)
      }
    end
  end
end
