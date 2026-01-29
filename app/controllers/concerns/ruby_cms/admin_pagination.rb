# frozen_string_literal: true

module RubyCms
  module AdminPagination
    extend ActiveSupport::Concern

    included do
      class_attribute :pagination_per_page, default: 50
      class_attribute :pagination_turbo_frame, default: nil
    end

    def set_pagination_vars(collection, per_page: nil, turbo_frame: nil)
      per_page ||= self.class.pagination_per_page
      turbo_frame ||= self.class.pagination_turbo_frame

      page = sanitize_page_param(params[:page])
      paginated, total_count, total_pages, offset = paginate_collection_internal(collection, page,
                                                                                 per_page)

      @pagination = build_pagination_hash(page, per_page, total_count, total_pages, offset)
      @pagination_path = build_pagination_path_lambda
      @turbo_frame = turbo_frame

      paginated
    end

    def paginate_collection(collection, per_page: nil, turbo_frame: nil)
      set_pagination_vars(collection, per_page:, turbo_frame:)
    end

    module ClassMethods
      def paginates(per_page: 50, turbo_frame: nil)
        self.pagination_per_page = per_page
        self.pagination_turbo_frame = turbo_frame
      end
    end

    private

    def sanitize_page_param(page_param)
      page = page_param.to_i
      [page, 1].max
    end

    def paginate_collection_internal(collection, page, per_page)
      if defined?(Kaminari) && collection.respond_to?(:page)
        paginated = collection.page(page).per(per_page)
        [paginated, paginated.total_count, paginated.total_pages, paginated.offset_value]
      else
        total_count = collection.count
        offset = (page - 1) * per_page
        paginated = collection.limit(per_page).offset(offset)
        [paginated, total_count, (total_count.to_f / per_page).ceil, offset]
      end
    end

    def build_pagination_hash(page, per_page, total_count, total_pages, offset)
      {
        current_page: page,
        total_pages: total_pages,
        total_count: total_count,
        per_page: per_page,
        has_next: page < total_pages,
        has_previous: page > 1,
        next_page: page < total_pages ? page + 1 : nil,
        previous_page: page > 1 ? page - 1 : nil,
        start_item: total_count.positive? ? offset + 1 : 0,
        end_item: [offset + per_page, total_count].min
      }
    end

    def build_pagination_path_lambda
      lambda do |page_num|
        query_params = request.query_parameters.except(:page).merge(page: page_num)
        base_path = request.path
        query_string = query_params.to_query
        query_string.present? ? "#{base_path}?#{query_string}" : base_path
      end
    end
  end
end
