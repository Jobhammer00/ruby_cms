# frozen_string_literal: true

require "rails_helper"

RSpec.describe RubyCms::Settings do
  before(:all) do
    ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")

    ActiveRecord::Schema.define do
      create_table :preferences, force: true do |t|
        t.string :key, null: false
        t.text :value
        t.string :value_type, default: "string", null: false
        t.text :description
        t.string :category, default: "general"
        t.timestamps
      end
    end
  end

  before do
    RubyCms::Preference.delete_all
    RubyCms::SettingsRegistry.seed_defaults!
    described_class.ensure_defaults!

    Rails.application.config.ruby_cms.analytics_max_popular_pages = 33
    Rails.application.config.ruby_cms.analytics_rapid_request_threshold = 77
    Rails.application.config.ruby_cms.analytics_cache_duration_seconds = 120
    Rails.application.config.ruby_cms.pagination_min_per_page = 10
    Rails.application.config.ruby_cms.reserved_key_prefixes = %w[admin_ internal_]
  end

  it "imports initializer values once and persists sentinel" do
    first = described_class.import_initializer_values!

    expect(first[:skipped]).to eq(false)
    expect(first[:imported_count]).to be > 0
    expect(first[:imported_keys]).to include(
      "analytics_max_popular_pages",
      "analytics_rapid_request_threshold",
      "analytics_cache_duration_seconds",
      "pagination_min_per_page",
      "reserved_key_prefixes"
    )

    expect(described_class.get(:analytics_max_popular_pages)).to eq(33)
    expect(described_class.get(:analytics_rapid_request_threshold)).to eq(77)
    expect(described_class.get(:analytics_cache_duration_seconds)).to eq(120)
    expect(described_class.get(:pagination_min_per_page)).to eq(10)
    expect(described_class.get(:reserved_key_prefixes)).to eq(%w[admin_ internal_])
    expect(described_class.imported_from_initializer?).to eq(true)

    second = described_class.import_initializer_values!
    expect(second[:skipped]).to eq(true)
    expect(second[:reason]).to eq("already imported")
  end

  it "re-imports when force is true" do
    described_class.import_initializer_values!
    Rails.application.config.ruby_cms.analytics_max_popular_pages = 55

    forced = described_class.import_initializer_values!(force: true)

    expect(forced[:skipped]).to eq(false)
    expect(described_class.get(:analytics_max_popular_pages)).to eq(55)
  end
end
