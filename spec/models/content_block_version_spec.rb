# frozen_string_literal: true

require "rails_helper"

RSpec.describe ContentBlockVersion do
  before(:all) do
    ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")

    ActiveRecord::Schema.define do
      create_table :users, force: true do |t|
        t.string :email
        t.timestamps
      end

      create_table :content_blocks, force: true do |t|
        t.string :key, null: false
        t.string :locale, null: false, default: "en"
        t.string :title
        t.text :content
        t.string :content_type, null: false, default: "text"
        t.boolean :published, null: false, default: false
        t.integer :updated_by_id
        t.timestamps
      end

      create_table :content_block_versions, force: true do |t|
        t.integer :content_block_id, null: false
        t.integer :user_id
        t.integer :version_number, null: false
        t.string :title, null: false
        t.text :content
        t.text :rich_content_html
        t.string :content_type, null: false
        t.boolean :published, null: false, default: true
        t.string :event, null: false, default: "update"
        t.text :metadata
        t.datetime :created_at, null: false
      end
    end
  end

  before do
    ContentBlockVersion.delete_all
    ContentBlock.delete_all
  end

  describe "validations" do
    let(:content_block) do
      ContentBlock.create!(
        key: "validation_block",
        locale: "en",
        title: "Validation block",
        content: "Validation",
        content_type: "text",
        published: true
      )
    end

    it "requires version_number" do
      version = described_class.new(
        content_block: content_block,
        version_number: nil,
        title: "Title",
        content: "Content",
        content_type: "text",
        published: true,
        event: "update",
        created_at: Time.current
      )

      expect(version).not_to be_valid
      expect(version.errors[:version_number]).to be_present
    end

    it "requires event to be in EVENTS" do
      version = described_class.new(
        content_block: content_block,
        version_number: 2,
        title: "Title",
        content: "Content",
        content_type: "text",
        published: true,
        event: "invalid_event",
        created_at: Time.current
      )

      expect(version).not_to be_valid
      expect(version.errors[:event]).to be_present
    end
  end

  describe "associations" do
    it "belongs to content_block" do
      association = described_class.reflect_on_association(:content_block)

      expect(association).not_to be_nil
      expect(association.macro).to eq(:belongs_to)
    end

    it "belongs to optional user" do
      association = described_class.reflect_on_association(:user)

      expect(association).not_to be_nil
      expect(association.macro).to eq(:belongs_to)
      expect(association.options[:optional]).to eq(true)
    end
  end

  describe "#diff_from" do
    let(:content_block) do
      ContentBlock.create!(
        key: "homepage_hero",
        locale: "en",
        title: "Homepage hero",
        content: "Welcome",
        content_type: "text",
        published: true
      )
    end

    let(:version_one) do
      ContentBlockVersion.create!(
        content_block: content_block,
        version_number: 2,
        title: "Original Title",
        content: "Original content",
        content_type: "text",
        published: true,
        event: "create",
        created_at: 2.days.ago
      )
    end

    let(:version_two) do
      ContentBlockVersion.create!(
        content_block: content_block,
        version_number: 3,
        title: "Updated Title",
        content: "Original content",
        content_type: "text",
        published: true,
        event: "update",
        created_at: 1.day.ago
      )
    end

    it "returns the correct diff" do
      expect(version_two.diff_from(version_one)).to eq(
        title: { old: version_one.title, new: version_two.title }
      )
    end

    it "returns an empty hash if there are no changes" do
      expect(version_one.diff_from(version_one)).to eq({})
    end
  end
end
