# frozen_string_literal: true

# Standalone unit spec - runs without Rails to avoid database.yml and engine setup.
# rubocop:disable RSpec/VerifiedDoubles
require "ostruct"
require_relative "../../lib/ruby_cms/content_blocks_grouping"

RSpec.describe RubyCms::ContentBlocksGrouping do
  before do
    content_block_model = double("ContentBlock.model_name", element: "content_block")
    stub_const("ContentBlock", Class.new)
    allow(ContentBlock).to receive(:model_name).and_return(content_block_model)
  end

  describe ".group_by_key" do
    let(:block_en) do
      double(
        "ContentBlock",
        key: "hero_title",
        id: 1,
        locale: "en",
        title: "Welcome",
        content_type: "text",
        published?: true
      )
    end

    let(:block_nl) do
      double(
        "ContentBlock",
        key: "hero_title",
        id: 2,
        locale: "nl",
        title: "Welkom",
        content_type: "text",
        published?: true
      )
    end

    let(:block_unpublished) do
      double(
        "ContentBlock",
        key: "footer",
        id: 3,
        locale: "en",
        title: "Footer",
        content_type: "text",
        published?: false
      )
    end

    let(:collection) { [block_en, block_nl, block_unpublished] }

    it "groups blocks by key" do
      result = described_class.group_by_key(collection)

      expect(result.size).to eq(2)
      expect(result.map(&:key)).to contain_exactly("hero_title", "footer")
    end

    it "joins locales for blocks with same key" do
      result = described_class.group_by_key(collection)
      hero_group = result.find {|r| r.key == "hero_title" }

      expect(hero_group.locale).to eq("en, nl")
    end

    it "uses first block's attributes for shared fields" do
      result = described_class.group_by_key(collection)
      hero_group = result.find {|r| r.key == "hero_title" }

      expect(hero_group.id).to eq(1)
      expect(hero_group.title).to eq("Welcome")
      expect(hero_group.content_type).to eq("text")
    end

    it "sets published? to true only when all blocks are published" do
      result = described_class.group_by_key(collection)
      hero_group = result.find {|r| r.key == "hero_title" }
      footer_group = result.find {|r| r.key == "footer" }

      expect(hero_group.published?).to be true
      expect(footer_group.published?).to be false
    end

    it "includes content_block reference to first block" do
      result = described_class.group_by_key(collection)
      hero_group = result.find {|r| r.key == "hero_title" }

      expect(hero_group.content_block).to eq(block_en)
    end

    it "responds to model_name for compatibility with row partial" do
      result = described_class.group_by_key(collection)
      hero_group = result.first

      expect(hero_group).to respond_to(:model_name)
      expect(hero_group.model_name.element).to eq("content_block")
    end

    it "sorts results by key" do
      result = described_class.group_by_key(collection)

      expect(result.map(&:key)).to eq(%w[footer hero_title])
    end

    it "handles empty collection" do
      result = described_class.group_by_key([])

      expect(result).to eq([])
    end

    it "handles single block" do
      result = described_class.group_by_key([block_en])

      expect(result.size).to eq(1)
      expect(result.first.key).to eq("hero_title")
      expect(result.first.locale).to eq("en")
    end
  end
end
# rubocop:enable RSpec/VerifiedDoubles
