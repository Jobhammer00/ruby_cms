# frozen_string_literal: true

module RubyCms
  module AdminPagination
    extend ActiveSupport::Concern

    included do
      # Default pagination settings
      class_attribute :pagination_per_page, default: 50
      class_attribute :pagination_turbo_frame, default: nil
    end

    # Set pagination instance variables for views
    # @param collection [ActiveRecord::Relation] The collection to paginate
    # @param per_page [Integer] Items per page (default: pagination_per_page)
    # @param turbo_frame [String, nil] Turbo Frame ID for pagination links
    def set_pagination_vars(collection, per_page: nil, turbo_frame: nil)
      per_page ||= self.class.pagination_per_page
      turbo_frame ||= self.class.pagination_turbo_frame

      page = params[:page]&.to_i || 1
      page = 1 if page < 1

      # Use Kaminari if available, otherwise manual pagination
      if defined?(Kaminari) && collection.respond_to?(:page)
        paginated = collection.page(page).per(per_page)
        total_count = paginated.total_count
        total_pages = paginated.total_pages
        offset = paginated.offset_value
      else
        # Manual pagination fallback
        total_count = collection.count
        total_pages = (total_count.to_f / per_page).ceil
        offset = (page - 1) * per_page
        paginated = collection.limit(per_page).offset(offset)
      end

      @pagination = {
        current_page: page,
        total_pages: total_pages,
        total_count: total_count,
        per_page: per_page,
        has_next: page < total_pages,
        has_previous: page > 1,
        next_page: page < total_pages ? page + 1 : nil,
        previous_page: page > 1 ? page - 1 : nil,
        start_item: total_count > 0 ? offset + 1 : 0,
        end_item: [offset + per_page, total_count].min
      }

      @pagination_path = lambda do |page_num|
        # Build URL with page as query parameter
        # Merge existing query params (except page) and add new page
        query_params = request.query_parameters.except(:page).merge(page: page_num)

        # Build base URL using request path (preserves any route params)
        base_path = request.path

        # Append query string
        query_string = query_params.to_query
        query_string.present? ? "#{base_path}?#{query_string}" : base_path
      end

      @turbo_frame = turbo_frame

      paginated
    end

    # Paginate a collection and set instance variables
    # @param collection [ActiveRecord::Relation] The collection to paginate
    # @param per_page [Integer] Items per page (default: pagination_per_page)
    # @param turbo_frame [String, nil] Turbo Frame ID for pagination links
    # @return [ActiveRecord::Relation] Paginated collection
    def paginate_collection(collection, per_page: nil, turbo_frame: nil)
      set_pagination_vars(collection, per_page:, turbo_frame:)
    end

    module ClassMethods
      # Configure pagination settings
      # @param per_page [Integer] Default items per page
      # @param turbo_frame [String, nil] Default Turbo Frame ID
      def paginates(per_page: 50, turbo_frame: nil)
        self.pagination_per_page = per_page
        self.pagination_turbo_frame = turbo_frame
      end
    end
  end
end
