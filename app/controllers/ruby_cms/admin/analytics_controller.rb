# frozen_string_literal: true

require "ipaddr"

module RubyCms
  module Admin
    class AnalyticsController < BaseController
      before_action { require_permission!(:manage_analytics) }
      before_action :set_date_range
      before_action :validate_date_range

      def index
        report = RubyCms::Analytics::Report.new(
          start_date: @start_date,
          end_date: @end_date,
          period: @period
        )
        @stats = report.dashboard_stats
        @stats.each {|key, value| instance_variable_set(:"@#{key}", value) }
        @active_users = active_users_count
      end

      def page_details
        @page_name = sanitize_page_name(params[:page_name])
        unless @page_name
          return redirect_to ruby_cms_admin_analytics_path,
                             alert: t("ruby_cms.admin.analytics.invalid_page_name",
                                      default: "Invalid page name.")
        end

        report = RubyCms::Analytics::Report.new(
          start_date: @start_date,
          end_date: @end_date,
          period: @period
        )
        data = report.page_stats(@page_name)
        @page_views = data[:page_views]
        @page_stats = data[:stats]
      end

      def visitor_details
        @ip_address = sanitize_ip_address(params[:ip_address])
        unless @ip_address
          return redirect_to ruby_cms_admin_analytics_path,
                             alert: t("ruby_cms.admin.analytics.invalid_ip_address",
                                      default: "Invalid IP address.")
        end

        report = RubyCms::Analytics::Report.new(
          start_date: @start_date,
          end_date: @end_date,
          period: @period
        )
        data = report.visitor_stats(@ip_address)
        @visitor_views = data[:visitor_views]
        @visitor_stats = data[:stats]
      end

      private

      def set_date_range
        @period = sanitize_period(params[:period]) || default_period

        @start_date, @end_date = parsed_date_range || default_date_range
      rescue Date::Error
        @start_date, @end_date = fallback_date_range
      end

      def validate_date_range
        max_days = RubyCms::Settings.get(:analytics_max_date_range_days, default: 365).to_i
        return if valid_date_range?(max_days)

        redirect_to ruby_cms_admin_analytics_path,
                    alert: "Invalid date range. Maximum range is #{max_days} days."
      end

      def active_users_count
        Ahoy::Event
          .where(name: RubyCms::Analytics::Report::EVENT_PAGE_VIEW)
          .where(time: 5.minutes.ago..)
          .joins(:visit)
          .distinct
          .count(:visitor_token)
      rescue StandardError
        nil
      end

      def sanitize_period(value)
        %w[day week month year].include?(value.to_s) ? value.to_s : nil
      end

      def default_period
        RubyCms::Settings.get(:analytics_default_period, default: "week").to_s
      rescue StandardError
        "week"
      end

      def period_start_date(period, end_date)
        case period
        when "day" then end_date
        when "week" then end_date - 6.days
        when "month" then end_date - 29.days
        else end_date - 364.days
        end
      end

      def sanitize_page_name(page_name)
        page_name.to_s.gsub(%r{[^a-zA-Z0-9_\-/]}, "").presence
      end

      def sanitize_ip_address(ip_address)
        return nil if ip_address.blank?

        IPAddr.new(ip_address)
        ip_address
      rescue IPAddr::InvalidAddressError
        nil
      end

      helper_method :format_chart_date, :format_chart_date_short

      def format_chart_date(date_string)
        format_chart_date_by_granularity(date_string, long: true)
      rescue Date::Error
        date_string.to_s
      end

      def format_chart_date_short(date_string)
        format_chart_date_by_granularity(date_string, long: false)
      rescue Date::Error
        date_string.to_s
      end

      def format_daily_date(date_string)
        date = Date.parse(date_string.to_s)
        if @period == "month"
          end_date = [date + 2.days, @end_date].min
          return "#{date.strftime('%b %d')} - #{end_date.strftime('%b %d')}" if date != end_date
        end
        date.strftime("%B %d, %Y")
      end

      def format_daily_date_short(date_string)
        date = Date.parse(date_string.to_s)
        if @period == "month"
          end_date = [date + 2.days, @end_date].min
          return "#{date.strftime('%m/%d')}-#{end_date.strftime('%m/%d')}" if date != end_date
        end
        date.strftime("%m/%d")
      end

      def parsed_date_range
        return nil unless params[:start_date].present? && params[:end_date].present?

        [
          Date.parse(params[:start_date]),
          Date.parse(params[:end_date])
        ]
      end

      def default_date_range
        end_date = Date.current
        [period_start_date(@period, end_date), end_date]
      end

      def fallback_date_range
        end_date = Date.current
        [end_date - 6.days, end_date]
      end

      def valid_date_range?(max_days)
        return false unless @end_date.between?(@start_date, Date.current)

        (@end_date - @start_date).to_i <= max_days
      end

      def format_chart_date_by_granularity(date_string, long:)
        str = date_string.to_s

        if str.match?(/\A\d{4}-\d{2}-\d{2}\z/)
          return long ? format_daily_date(str) : format_daily_date_short(str)
        end

        if str.match?(/\A\d{4}-\d{2}\z/)
          format_monthly_date(str, long:)
        elsif str.match?(/\A\d{2}\z/)
          format_hourly_date(str, long:)
        else
          str
        end
      end

      def format_monthly_date(date_string, long:)
        date = Date.parse("#{date_string}-01")
        long ? date.strftime("%B %Y") : date.strftime("%b")
      end

      def format_hourly_date(date_string, long:)
        long ? "#{date_string}:00" : "#{date_string}h"
      end
    end
  end
end
