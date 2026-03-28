# frozen_string_literal: true

# Host apps get Ahoy::Store from the install generator; the dummy app does not.
require "ahoy_matey"

unless defined?(Ahoy::Store)
  module Ahoy
    class Store < Ahoy::DatabaseStore
    end
  end
end
