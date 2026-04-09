# frozen_string_literal: true

# Performance indexes for RubyCMS analytics queries.
#
# Without these, every analytics page load does a full table scan on
# ahoy_events and ahoy_visits for the date range.
#
# Impact per index:
#   ahoy_events (name, time)      — primary filter for page_view_events + conversion_events
#   ahoy_events (visit_id, time)  — exit pages subquery: MAX(time) per visit
#   ahoy_visits (started_at)      — primary filter for visits scope
#   ahoy_visits (visitor_token)   — new-visitor NOT IN subquery
class AddAnalyticsPerformanceIndexes < ActiveRecord::Migration[7.1]
  def change
    return unless table_exists?(:ahoy_events) && table_exists?(:ahoy_visits)

    # Most critical: all page_view_events / conversion_events queries filter on (name, time)
    add_index :ahoy_events, %i[name time], if_not_exists: true

    # Exit pages subquery groups by visit_id and picks MAX(time)
    add_index :ahoy_events, %i[visit_id time], if_not_exists: true

    # All visits queries filter on started_at range
    add_index :ahoy_visits, :started_at, if_not_exists: true

    # New-visitor percentage: NOT IN (SELECT visitor_token WHERE started_at < ?)
    add_index :ahoy_visits, :visitor_token, if_not_exists: true
  end
end
