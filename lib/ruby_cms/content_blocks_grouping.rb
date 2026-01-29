# frozen_string_literal: true

module RubyCms
  module ContentBlocksGrouping
    Row = ::Struct.new(:key, :id, :locale, :title, :content_type, :published, :content_block,
                       keyword_init: true) do
      def published?
        published
      end

      def model_name # rubocop:disable Rails/Delegate
        ::ContentBlock.model_name
      end
    end

    class << self
      # rubocop:disable Rails/Blank -- use plain Ruby for standalone unit specs without Rails
      def group_by_key(collection)
        return [] if collection.nil? || collection.empty?

        collection
          .group_by(&:key)
          .map {|key, blocks| build_row(key, blocks) }
          .sort_by(&:key)
      end
      # rubocop:enable Rails/Blank

      def build_row(key, blocks)
        first = blocks.first
        Row.new(
          key: key,
          id: first.id,
          locale: blocks.map(&:locale).sort.join(", "),
          title: first.title,
          content_type: first.content_type,
          published: blocks.all?(&:published?),
          content_block: first
        )
      end
    end
  end
end
