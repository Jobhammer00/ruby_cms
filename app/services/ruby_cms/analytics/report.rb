# frozen_string_literal: true

module RubyCms
  module Analytics
    class Report
      DEFAULT_CACHE_DURATION_SECONDS = 600
      DEFAULT_MAX_POPULAR_PAGES = 10
      DEFAULT_MAX_TOP_VISITORS = 10
      DEFAULT_MAX_REFERRERS = 10
      DEFAULT_MAX_LANDING_PAGES = 10
      DEFAULT_MAX_UTM_SOURCES = 10
      DEFAULT_HIGH_VOLUME_THRESHOLD = 1000
      DEFAULT_RAPID_REQUEST_THRESHOLD = 50
      DEFAULT_RECENT_PAGE_VIEWS_LIMIT = 25
      DEFAULT_PAGE_DETAILS_LIMIT = 100
      DEFAULT_VISITOR_DETAILS_LIMIT = 100

      def initialize(start_date:, end_date:, period: nil)
        @start_date = start_date.to_date.beginning_of_day
        @end_date = end_date.to_date.end_of_day
        @period = period.presence || RubyCms::Settings.get(:analytics_default_period,
                                                           default: "week").to_s
        @range = @start_date..@end_date
      end

      def dashboard_stats
        Rails.cache.fetch(cache_key("dashboard"), expires_in: cache_duration) do
          {
            total_page_views: page_view_events.count,
            unique_visitors: visits.distinct.count(:visitor_token),
            total_sessions: visits.distinct.count(:visit_token),
            popular_pages: popular_pages_data,
            top_visitors: top_visitors_data,
            hourly_activity: hourly_activity_data,
            daily_activity: daily_activity_data,
            daily_visitors: daily_visitors_data,
            top_referrers: referrer_data,
            landing_pages: landing_pages_data,
            utm_sources: utm_sources_data,
            browser_stats: visits.where.not(browser: [nil, ""]).group(:browser).count,
            device_stats: visits.where.not(device_type: [nil, ""]).group(:device_type).count,
            os_stats: visits.where.not(os: [nil, ""]).group(:os).count,
            suspicious_activity: suspicious_activity_data,
            recent_page_views: page_view_events.order(time: :desc).limit(recent_page_views_limit),
            extra_cards: extra_cards_data
          }
        end
      end

      def page_stats(page_name)
        scoped = page_view_events.where(page_name:)

        {
          page_views: scoped.order(time: :desc).limit(page_details_limit),
          stats: {
            total_views: scoped.count,
            unique_visitors: scoped.joins(:visit).distinct.count("ahoy_visits.visitor_token"),
            avg_views_per_day: (scoped.count.to_f / days_in_range).round(2)
          }
        }
      end

      def visitor_stats(ip_address)
        visitor_visits = visits.where(ip: ip_address)
        visitor_events = page_view_events.joins(:visit).where(ahoy_visits: { ip: ip_address })

        {
          visitor_views: visitor_events.order(time: :desc).limit(visitor_details_limit),
          stats: {
            total_views: visitor_events.count,
            unique_pages: visitor_events.where.not(page_name: [nil, ""]).distinct.count(:page_name),
            first_visit: visitor_visits.minimum(:started_at),
            last_visit: visitor_visits.maximum(:started_at)
          }
        }
      end

      private

      def ruby_cms_config
        Rails.application.config.ruby_cms
      end

      def cache_duration
        RubyCms::Settings.get(
          :analytics_cache_duration_seconds,
          default: DEFAULT_CACHE_DURATION_SECONDS
        ).to_i.seconds
      rescue StandardError
        DEFAULT_CACHE_DURATION_SECONDS.seconds
      end

      def cache_key(suffix)
        "ruby_cms:analytics:#{@start_date.to_date}:#{@end_date.to_date}:#{@period}:#{suffix}"
      end

      def visits
        base = Ahoy::Visit.where(started_at: @range)
        # Use all visits by default so existing DB records are included. Bot exclusion
        # can be applied via config.analytics_visit_scope (e.g. ->(s) { s.exclude_bots }).
        apply_visit_scope_hook(base)
      end

      def page_view_events
        base = Ahoy::Event.where(name: "page_view", time: @range).joins(:visit).merge(visits)
        apply_event_scope_hook(base)
      end

      def apply_visit_scope_hook(scope)
        hook = ruby_cms_config.analytics_visit_scope
        return scope unless hook.respond_to?(:call)

        hook.call(scope)
      rescue StandardError
        scope
      end

      def apply_event_scope_hook(scope)
        hook = ruby_cms_config.analytics_event_scope
        return scope unless hook.respond_to?(:call)

        hook.call(scope)
      rescue StandardError
        scope
      end

      def popular_pages_data
        limit = RubyCms::Settings.get(:analytics_max_popular_pages,
                                      default: DEFAULT_MAX_POPULAR_PAGES).to_i

        page_view_events
          .where.not(page_name: [nil, ""])
          .group(:page_name)
          .order(Arel.sql("count_all DESC"))
          .limit(limit)
          .count
      end

      def top_visitors_data
        limit = RubyCms::Settings.get(:analytics_max_top_visitors,
                                      default: DEFAULT_MAX_TOP_VISITORS).to_i
        visits.group(:ip).order(Arel.sql("COUNT(*) DESC")).limit(limit).count
      end

      def hourly_activity_data
        # Portable: group in Ruby so we work on SQLite, PostgreSQL, MySQL
        raw = page_view_events.pluck(:time).each_with_object(Hash.new(0)) do |t, acc|
          acc[t.utc.strftime("%H")] += 1
        end
        ("00".."23").index_with {|h| raw[h] || 0 }.sort.to_h
      end

      def daily_activity_data
        case @period
        when "day"
          hourly_activity_data
        when "year"
          group_by_month
        else
          group_by_date
        end
      end

      def group_by_date
        result = Hash.new(0)
        page_view_events.pluck(:time).each do |time|
          result[time.to_date.strftime("%Y-%m-%d")] += 1
        end
        fill_date_gaps(result)
      end

      def group_by_month
        raw = page_view_events.pluck(:time).each_with_object(Hash.new(0)) do |t, acc|
          acc[t.strftime("%Y-%m")] += 1
        end
        fill_month_gaps(raw)
      end

      def fill_month_gaps(data)
        result = {}
        current = @start_date.to_date.beginning_of_month
        end_month = @end_date.to_date.beginning_of_month
        while current <= end_month
          key = current.strftime("%Y-%m")
          result[key] = data[key] || 0
          current = current.next_month
        end
        result
      end

      def daily_visitors_data
        case @period
        when "day"
          {}
        when "year"
          group_visitors_by_month
        else
          group_visitors_by_date
        end
      end

      def group_visitors_by_date
        h = visits.pluck(:visitor_token, :started_at).each_with_object(Hash.new do |hash, k|
          hash[k] = Set.new
        end) do |(vt, st), acc|
          next if st.blank?

          key = st.respond_to?(:strftime) ? st.strftime("%Y-%m-%d") : st.to_s[0, 10]
          acc[key] << vt
        end
        fill_date_gaps(h.transform_values(&:size))
      end

      def group_visitors_by_month
        h = visits.pluck(:visitor_token, :started_at).each_with_object(Hash.new do |hash, k|
          hash[k] = Set.new
        end) do |(vt, st), acc|
          next if st.blank?

          key = st.respond_to?(:strftime) ? st.strftime("%Y-%m") : st.to_s[0, 7]
          acc[key] << vt
        end
        raw = h.transform_values(&:size)
        fill_month_gaps(raw)
      end

      def referrer_data
        limit = RubyCms::Settings.get(:analytics_max_referrers, default: DEFAULT_MAX_REFERRERS).to_i
        return {} unless Ahoy::Visit.column_names.include?("referrer")

        visits.where.not(referrer: [nil, ""])
              .group(:referrer)
              .order(Arel.sql("COUNT(*) DESC"))
              .limit(limit)
              .count
      end

      def landing_pages_data
        limit = RubyCms::Settings.get(:analytics_max_landing_pages,
                                      default: DEFAULT_MAX_LANDING_PAGES).to_i
        return {} unless Ahoy::Visit.column_names.include?("landing_page")

        visits.where.not(landing_page: [nil, ""])
              .group(:landing_page)
              .order(Arel.sql("COUNT(*) DESC"))
              .limit(limit)
              .count
      end

      def utm_sources_data
        limit = RubyCms::Settings.get(:analytics_max_utm_sources,
                                      default: DEFAULT_MAX_UTM_SOURCES).to_i
        return {} unless Ahoy::Visit.column_names.include?("utm_source")

        raw = visits.where.not(utm_source: [nil, ""])
                    .group(:utm_source, :utm_medium)
                    .order(Arel.sql("COUNT(*) DESC"))
                    .limit(limit)
                    .count
        raw.transform_keys do |(source, medium)|
          "#{source}#{" / #{medium}" if medium.present?}"
        end
      end

      def suspicious_activity_data
        [].tap do |items|
          add_high_volume_ips(items)
          add_rapid_requests(items)
        end
      end

      def add_high_volume_ips(items)
        threshold = RubyCms::Settings.get(
          :analytics_high_volume_threshold,
          default: DEFAULT_HIGH_VOLUME_THRESHOLD
        ).to_i

        visits.group(:ip).having("COUNT(*) > ?", threshold).count.each do |ip, count|
          items << {
            type: "high_volume",
            ip: ip,
            count: count,
            description: "High volume traffic from IP #{ip}"
          }
        end
      end

      def add_rapid_requests(items)
        threshold = RubyCms::Settings.get(
          :analytics_rapid_request_threshold,
          default: DEFAULT_RAPID_REQUEST_THRESHOLD
        ).to_i

        per_ip_per_minute = Hash.new(0)
        visits.pluck(:ip, :started_at).each do |ip, started_at|
          next if started_at.blank?

          minute_key = if started_at.respond_to?(:strftime)
                         started_at.strftime("%Y-%m-%d %H:%M")
                       else
                         started_at.to_s[0,
                                         16]
                       end
          per_ip_per_minute[[ip, minute_key]] += 1
        end

        per_ip_per_minute.each do |(ip, minute_key), count|
          next unless count > threshold

          items << {
            type: "rapid_requests",
            ip: ip,
            count: count,
            description: "Rapid requests from #{ip} at #{minute_key}"
          }
        end
      end

      def fill_date_gaps(data)
        (@start_date.to_date..@end_date.to_date).each_with_object({}) do |date, acc|
          key = date.strftime("%Y-%m-%d")
          acc[key] = data[key] || 0
        end
      end

      def extra_cards_data
        hook = ruby_cms_config.analytics_extra_cards
        return [] unless hook.respond_to?(:call)

        cards = hook.call(
          start_date: @start_date.to_date,
          end_date: @end_date.to_date,
          period: @period,
          visits_scope: visits,
          events_scope: page_view_events
        )
        Array(cards)
      rescue StandardError
        []
      end

      def days_in_range
        (@end_date.to_date - @start_date.to_date + 1).to_i
      end

      def recent_page_views_limit
        RubyCms::Settings.get(:analytics_recent_page_views_limit,
                              default: DEFAULT_RECENT_PAGE_VIEWS_LIMIT).to_i
      end

      def page_details_limit
        RubyCms::Settings.get(:analytics_page_details_limit,
                              default: DEFAULT_PAGE_DETAILS_LIMIT).to_i
      end

      def visitor_details_limit
        RubyCms::Settings.get(:analytics_visitor_details_limit,
                              default: DEFAULT_VISITOR_DETAILS_LIMIT).to_i
      end
    end
  end
end
