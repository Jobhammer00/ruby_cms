# frozen_string_literal: true

require "rails_helper"

RSpec.describe RubyCms::SettingsRegistry do
  before do
    described_class.entries = {}
    described_class.seed_defaults!
  end

  it "seeds expected keys across categories" do
    defaults = described_class.defaults_hash

    expect(defaults).to include(
      :nav_show_analytics,
      :analytics_high_volume_threshold,
      :analytics_cache_duration_seconds,
      :pagination_min_per_page,
      :pagination_max_per_page,
      :image_max_size,
      :dashboard_recent_errors_limit
    )
  end

  it "stores metadata (type/category/default) for entries" do
    entry = described_class.fetch(:analytics_cache_duration_seconds)

    expect(entry).not_to be_nil
    expect(entry.type).to eq(:integer)
    expect(entry.category).to eq("analytics")
    expect(entry.default).to eq(600)
  end
end
