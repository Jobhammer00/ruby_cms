# frozen_string_literal: true

module RubyCms
  module Admin
    class VisitorErrorsController < BaseController
      include RubyCms::AdminPagination
      include RubyCms::AdminTurboTable

      paginates per_page: -> { RubyCms::Preference.get(:visitor_errors_per_page, default: 25) },
                turbo_frame: "admin_table_content"

      before_action { require_permission!(:manage_visitor_errors) }
      before_action :set_visitor_error, only: %i[show resolve]

      def index
        scope = RubyCms::VisitorError.recent
        scope = scope.where(resolved: params[:resolved] == "true") if params[:resolved].present?
        scope = apply_search_filter(scope)
        scope = apply_error_type_filter(scope)
        @visitor_errors = set_pagination_vars(scope)
        render_index
      end

      def show
      end

      def resolve
        @visitor_error.update!(resolved: true)
        redirect_to ruby_cms_admin_visitor_errors_path,
                    notice: t("ruby_cms.admin.visitor_errors.resolved")
      end

      def bulk_delete
        ids = Array(params[:item_ids]).filter_map(&:to_i)
        count = RubyCms::VisitorError.where(id: ids).destroy_all.size
        redirect_to ruby_cms_admin_visitor_errors_path,
                    notice: t("ruby_cms.admin.visitor_errors.bulk_deleted", count:)
      end

      def bulk_mark_as_resolved
        ids = Array(params[:item_ids]).filter_map(&:to_i)
        count = RubyCms::VisitorError.where(id: ids).update_all(resolved: true)
        redirect_to ruby_cms_admin_visitor_errors_path,
                    notice: t("ruby_cms.admin.visitor_errors.bulk_resolved", count:)
      end

      private

      def set_visitor_error
        @visitor_error = RubyCms::VisitorError.find(params[:id])
      end

      def apply_search_filter(scope)
        return scope if params[:search].blank?

        term = sanitize_search_term(params[:search])
        scope.where("request_path ILIKE ?", "%#{term}%")
      end

      def apply_error_type_filter(scope)
        return scope if params[:error_type].blank?

        term = sanitize_search_term(params[:error_type])
        scope.where("error_class ILIKE ?", "%#{term}%")
      end

      def sanitize_search_term(term)
        term.to_s.strip.gsub(/[%_\\]/, "").truncate(100)
      end

      def render_index
        if turbo_frame_request?
          render :index, layout: false
        else
          render :index
        end
      end
    end
  end
end
