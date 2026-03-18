# frozen_string_literal: true

require "rails_helper"

RSpec.describe RubyCms::Settings do
  around do |example|
    if ActiveRecord::Base.connected?
      previous_db_config =
        ActiveRecord::Base.connection_db_config&.configuration_hash
    end

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

    example.run
  ensure
    ActiveRecord::Base.clear_all_connections!

    if previous_db_config
      ActiveRecord::Base.establish_connection(previous_db_config)
    else
      ActiveRecord::Base.remove_connection
    end
  end

  before do
    RubyCms::Preference.delete_all
    RubyCms::SettingsRegistry.seed_defaults!
    described_class.ensure_defaults!
  end

  it "returns registry default when preference row is missing" do
    RubyCms::Preference.where(key: "nav_show_analytics").delete_all
    expect(described_class.get(:nav_show_analytics)).to eq(true)
  end

  it "coerces values based on registry type when setting" do
    described_class.set(:analytics_max_top_visitors, "12")
    described_class.set(:nav_show_analytics, "false")
    described_class.set(:reserved_key_prefixes, '["admin_","internal_"]')

    expect(described_class.get(:analytics_max_top_visitors)).to eq(12)
    expect(described_class.get(:nav_show_analytics)).to eq(false)
    expect(described_class.get(:reserved_key_prefixes)).to eq(%w[admin_ internal_])
  end

  it "returns fallback default for unknown key" do
    expect(described_class.get(:unknown_setting_key, default: "fallback")).to eq("fallback")
  end

  it "returns all persisted settings as typed hash" do
    described_class.set(:analytics_max_popular_pages, 7)
    described_class.set(:nav_show_users, true)

    all = described_class.all

    expect(all[:analytics_max_popular_pages]).to eq(7)
    expect(all[:nav_show_users]).to eq(true)
  end
end
