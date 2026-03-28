# frozen_string_literal: true

require "rails_helper"
require_relative "../../app/models/content_block"

RSpec.describe ContentBlock do
  describe ".action_text_available?" do
    it "returns false when no database connection is available" do
      allow(ActiveRecord::Base).to receive(:connection)
        .and_raise(ActiveRecord::ConnectionNotEstablished.new("not connected"))

      expect(described_class.action_text_available?).to be(false)
    end
  end
end
