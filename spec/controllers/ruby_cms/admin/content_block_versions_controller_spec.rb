# frozen_string_literal: true

require "rails_helper"

RSpec.describe RubyCms::Admin::ContentBlockVersionsController, type: :controller do
  routes { RubyCms::Engine.routes }

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

  before do
    ContentBlockVersion.delete_all
    ContentBlock.delete_all

    allow(controller).to receive(:current_user_cms).and_return(instance_double(User, can?: true))
  end

  describe "GET index" do
    it "returns a success response" do
      get :index, params: { content_block_id: content_block.id }
      expect(response).to be_successful
    end
  end

  describe "GET show" do
    it "returns a success response" do
      get :show, params: { content_block_id: content_block.id, id: content_block.versions.first.id }
      expect(response).to be_successful
    end
  end
end
