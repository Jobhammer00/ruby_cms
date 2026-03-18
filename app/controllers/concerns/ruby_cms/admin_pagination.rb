# frozen_string_literal: true

require "ruby_cms/settings"

module RubyCms
  # Unified pagination concern for all admin index pages.
  # Uses RubyCms::Preference for per_page when configured via paginates(per_page: proc).
  module AdminPagination
    extend ActiveSupport::Concern

    DEFAULT_MIN_PER_PAGE = 5
    DEFAULT_MAX_PER_PAGE = 200

    included do
      class_attribute :pagination_per_page, default: 50
      class_attribute :pagination_turbo_frame, default: nil
      class_attribute :pagination_min_per_page, default: DEFAULT_MIN_PER_PAGE
      class_attribute :pagination_max_per_page, default: DEFAULT_MAX_PER_PAGE
    end

    def set_pagination_vars(collection, per_page: nil, turbo_frame: nil)
      per_page = calculate_per_page(per_page)
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
      def paginates(per_page: 50, turbo_frame: nil, min_per_page: nil, max_per_page: nil)
        self.pagination_per_page = per_page
        self.pagination_turbo_frame = turbo_frame
        self.pagination_min_per_page = min_per_page if min_per_page.present?
        self.pagination_max_per_page = max_per_page if max_per_page.present?
      end
    end

    private

    def calculate_per_page(per_page=nil)
      per_page ||= self.class.pagination_per_page
      per_page = per_page.call if per_page.respond_to?(:call)

      min = RubyCms::Settings.get(:pagination_min_per_page,
                                  default: self.class.pagination_min_per_page).to_i
      max = RubyCms::Settings.get(:pagination_max_per_page,
                                  default: self.class.pagination_max_per_page).to_i
      max = [max, min].max

      per_page.to_i.clamp(min, max)
    end

    def sanitize_page_param(page_param)
      page = (page_param || params[:page]).to_i
      [page, 1].max
    end

    def paginate_collection_internal(collection, page, per_page)
      if collection.kind_of?(Array)
        paginate_array(collection, page, per_page)
      elsif defined?(Kaminari) && collection.respond_to?(:page)
        paginated = collection.page(page).per(per_page)
        [paginated, paginated.total_count, paginated.total_pages, paginated.offset_value]
      else
        paginate_relation(collection, page, per_page)
      end
    end

    def paginate_array(array, page, per_page)
      total_count = array.size
      offset = (page - 1) * per_page
      total_pages = total_count.positive? ? (total_count.to_f / per_page).ceil : 1
      paginated = array.slice(offset, per_page) || []
      [paginated, total_count, total_pages, offset]
    end

    def paginate_relation(collection, page, per_page)
      total_count = collection.count
      offset = (page - 1) * per_page
      total_pages = total_count.positive? ? (total_count.to_f / per_page).ceil : 1
      paginated = collection.limit(per_page).offset(offset)
      [paginated, total_count, total_pages, offset]
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
