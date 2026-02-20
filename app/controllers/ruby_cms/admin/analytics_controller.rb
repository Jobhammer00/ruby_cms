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
        @stats.each { |key, value| instance_variable_set(:"@#{key}", value) }
      end

      def page_details
        @page_name = sanitize_page_name(params[:page_name])
        return redirect_to ruby_cms_admin_analytics_path, alert: "Invalid page name." unless @page_name

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
        return redirect_to ruby_cms_admin_analytics_path, alert: "Invalid IP address." unless @ip_address

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

        if params[:start_date].present? && params[:end_date].present?
          @start_date = Date.parse(params[:start_date])
          @end_date = Date.parse(params[:end_date])
          return
        end

        @end_date = Date.current
        @start_date = period_start_date(@period, @end_date)
      rescue Date::Error
        @end_date = Date.current
        @start_date = @end_date - 6.days
      end

      def validate_date_range
        max_days = RubyCms::Settings.get(:analytics_max_date_range_days, default: 365).to_i
        return if @start_date <= @end_date &&
                  @end_date <= Date.current &&
                  ((@end_date - @start_date).to_i <= max_days)

        redirect_to ruby_cms_admin_analytics_path,
                    alert: "Invalid date range. Maximum range is #{max_days} days."
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
        page_name.to_s.gsub(/[^a-zA-Z0-9_\-\/]/, "").presence
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
        case date_string.to_s
        when /\A\d{4}-\d{2}-\d{2}\z/
          format_daily_date(date_string)
        when /\A\d{4}-\d{2}\z/
          Date.parse("#{date_string}-01").strftime("%B %Y")
        when /\A\d{2}\z/
          "#{date_string}:00"
        else
          date_string.to_s
        end
      rescue Date::Error
        date_string.to_s
      end

      def format_chart_date_short(date_string)
        case date_string.to_s
        when /\A\d{4}-\d{2}-\d{2}\z/
          format_daily_date_short(date_string)
        when /\A\d{4}-\d{2}\z/
          Date.parse("#{date_string}-01").strftime("%b")
        when /\A\d{2}\z/
          "#{date_string}h"
        else
          date_string.to_s
        end
      rescue Date::Error
        date_string.to_s
      end

      def format_daily_date(date_string)
        date = Date.parse(date_string.to_s)
        if @period == "month"
          end_date = [date + 2.days, @end_date].min
          return "#{date.strftime("%b %d")} - #{end_date.strftime("%b %d")}" if date != end_date
        end
        date.strftime("%B %d, %Y")
      end

      def format_daily_date_short(date_string)
        date = Date.parse(date_string.to_s)
        if @period == "month"
          end_date = [date + 2.days, @end_date].min
          return "#{date.strftime("%m/%d")}-#{end_date.strftime("%m/%d")}" if date != end_date
        end
        date.strftime("%m/%d")
      end
    end
  end
end
