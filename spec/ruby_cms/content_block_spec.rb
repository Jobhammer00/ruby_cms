# frozen_string_literal: true

require "rails_helper"
require_relative "../../app/models/content_block"

RSpec.describe ContentBlock do
  describe "rich text and attachment associations" do
    it "defines rich_content association when ActionText is loaded" do
      skip "ActionText not loaded in test environment" unless defined?(ActionText::RichText)

      expect(described_class.reflect_on_association(:rich_content)).to be_present
    end

    it "defines image association when ActiveStorage is loaded" do
      skip "ActiveStorage not loaded in test environment" unless defined?(ActiveStorage::Blob)

      expect(described_class.reflect_on_association(:image)).to be_present
    end
  end

  describe ".action_text_available?" do
    it "returns false when no database connection is available" do
      allow(ActiveRecord::Base).to receive(:connection)
        .and_raise(ActiveRecord::ConnectionNotEstablished.new("not connected"))

      expect(described_class.action_text_available?).to be(false)
    end
  end
end
