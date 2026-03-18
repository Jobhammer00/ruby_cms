# frozen_string_literal: true

require "rails_helper"
require "securerandom"

RSpec.describe RubyCms::Analytics::Report, type: :model do
  include ActiveSupport::Testing::TimeHelpers

  before(:all) do
    ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")

    ActiveRecord::Schema.define do
      create_table :ahoy_visits, force: true do |t|
        t.string :visit_token
        t.string :visitor_token
        t.datetime :started_at
        t.string :ip
        t.string :browser
        t.string :os
        t.string :device_type
      end

      create_table :ahoy_events, force: true do |t|
        t.string :name
        t.integer :visit_id
        t.datetime :time
        t.string :page_name
        t.string :request_path
      end

      create_table :preferences, force: true do |t|
        t.string :key, null: false
        t.text :value
        t.string :value_type, default: "string", null: false
        t.text :description
        t.string :category, default: "general"
        t.timestamps
      end
    end

    unless defined?(Ahoy::Visit)
      module Ahoy
        class Visit < ::ApplicationRecord
          self.table_name = "ahoy_visits"
          has_many :events, class_name: "Ahoy::Event", foreign_key: :visit_id, inverse_of: :visit
        end

        class Event < ::ApplicationRecord
          self.table_name = "ahoy_events"
          belongs_to :visit, class_name: "Ahoy::Visit", optional: true, inverse_of: :events
        end
      end
    end
  end

  before do
    Ahoy::Event.delete_all
    Ahoy::Visit.delete_all
    RubyCms::Preference.delete_all
    RubyCms::SettingsRegistry.seed_defaults!
    RubyCms::Settings.ensure_defaults!
    Rails.cache.clear
  end

  around do |example|
    travel_to(Time.zone.local(2026, 2, 1, 12, 0, 0)) { example.run }
  end

  def create_visit(ip:, started_at: Time.current, visitor_token: SecureRandom.uuid,
                   visit_token: SecureRandom.uuid)
    Ahoy::Visit.create!(
      visit_token: visit_token,
      visitor_token: visitor_token,
      started_at: started_at,
      ip: ip,
      browser: "Firefox",
      os: "Mac",
      device_type: "Desktop"
    )
  end

  def create_page_view(visit:, page_name:, time: Time.current)
    Ahoy::Event.create!(
      name: "page_view",
      visit: visit,
      time: time,
      page_name: page_name,
      request_path: "/#{page_name}"
    )
  end

  it "returns dashboard stats from ahoy events" do
    visit = create_visit(ip: "1.2.3.4")
    create_page_view(visit: visit, page_name: "home")

    report = described_class.new(
      start_date: Date.current - 1.day,
      end_date: Date.current,
      period: "week"
    )

    stats = report.dashboard_stats

    expect(stats[:total_page_views]).to eq(1)
    expect(stats[:unique_visitors]).to eq(1)
    expect(stats[:popular_pages]["home"]).to eq(1)
  end

  it "respects settings-driven limits for dashboard and detail pages" do
    RubyCms::Settings.set(:analytics_max_popular_pages, 1)
    RubyCms::Settings.set(:analytics_recent_page_views_limit, 2)
    RubyCms::Settings.set(:analytics_page_details_limit, 1)
    RubyCms::Settings.set(:analytics_visitor_details_limit, 1)

    visit = create_visit(ip: "8.8.8.8")
    create_page_view(visit: visit, page_name: "home", time: 3.minutes.ago)
    create_page_view(visit: visit, page_name: "about", time: 2.minutes.ago)
    create_page_view(visit: visit, page_name: "home", time: 1.minute.ago)

    report = described_class.new(
      start_date: Date.current - 1.day,
      end_date: Date.current,
      period: "week"
    )

    dashboard = report.dashboard_stats
    page_details = report.page_stats("home")
    visitor_details = report.visitor_stats("8.8.8.8")

    expect(dashboard[:popular_pages].size).to eq(1)
    expect(dashboard[:recent_page_views].size).to eq(2)
    expect(page_details[:page_views].size).to eq(1)
    expect(visitor_details[:visitor_views].size).to eq(1)
  end

  it "flags suspicious activity using configured thresholds" do
    RubyCms::Settings.set(:analytics_high_volume_threshold, 2)
    RubyCms::Settings.set(:analytics_rapid_request_threshold, 2)

    ip = "9.9.9.9"
    3.times do
      visit = create_visit(ip: ip, started_at: Time.current.change(sec: 0))
      create_page_view(visit: visit, page_name: "home", time: Time.current.change(sec: 0))
    end

    report = described_class.new(
      start_date: Date.current - 1.day,
      end_date: Date.current,
      period: "week"
    )

    suspicious = report.dashboard_stats[:suspicious_activity]
    types = suspicious.map {|item| item[:type] }

    expect(types).to include("high_volume")
    expect(types).to include("rapid_requests")
  end
end
