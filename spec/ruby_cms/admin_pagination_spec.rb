# frozen_string_literal: true

require "rails_helper"

RSpec.describe RubyCms::AdminPagination do
  class PaginationDummy
    include RubyCms::AdminPagination

    paginates per_page: -> { RubyCms.setting(:content_blocks_per_page, default: 50) }

    attr_reader :params, :request

    def initialize(params: {}, query: {}, path: "/admin/content_blocks")
      @params = params.with_indifferent_access
      @request = Struct.new(:query_parameters, :path).new(query.with_indifferent_access, path)
    end
  end

  it "clamps per_page to settings max" do
    allow(RubyCms).to receive(:setting).and_wrap_original do |orig, key, default: nil|
      case key.to_sym
      when :content_blocks_per_page then 500
      else orig.call(key, default: default)
      end
    end
    allow(RubyCms::Settings).to receive(:get).and_call_original
    allow(RubyCms::Settings).to receive(:get).with(:pagination_min_per_page, default: 5).and_return(10)
    allow(RubyCms::Settings).to receive(:get).with(:pagination_max_per_page, default: 200).and_return(25)

    dummy = PaginationDummy.new(params: { page: 1 })
    result = dummy.paginate_collection((1..100).to_a)

    pagination = dummy.instance_variable_get(:@pagination)
    expect(pagination[:per_page]).to eq(25)
    expect(result.length).to eq(25)
  end

  it "clamps per_page to settings min" do
    allow(RubyCms).to receive(:setting).and_wrap_original do |orig, key, default: nil|
      case key.to_sym
      when :content_blocks_per_page then 1
      else orig.call(key, default: default)
      end
    end
    allow(RubyCms::Settings).to receive(:get).and_call_original
    allow(RubyCms::Settings).to receive(:get).with(:pagination_min_per_page, default: 5).and_return(10)
    allow(RubyCms::Settings).to receive(:get).with(:pagination_max_per_page, default: 200).and_return(200)

    dummy = PaginationDummy.new(params: { page: 1 })
    result = dummy.paginate_collection((1..100).to_a)

    pagination = dummy.instance_variable_get(:@pagination)
    expect(pagination[:per_page]).to eq(10)
    expect(result.length).to eq(10)
  end
end
