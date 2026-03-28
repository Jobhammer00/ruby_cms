# frozen_string_literal: true

require "rails_helper"

RSpec.describe ContentBlock::Versionable do
  it "is included in ContentBlock" do
    expect(ContentBlock.included_modules).to include(described_class)
  end
end
