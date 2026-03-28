# frozen_string_literal: true

# Loaded as Rails.application.routes only in specs. The gem's root config/routes.rb
# draws RubyCms::Engine.routes; loading it here too duplicates named routes (e.g.
# ruby_cms_admin_root). Engine routes remain on RubyCms::Engine.routes.
Rails.application.routes.draw do
  get "/__ruby_cms_test__", to: proc { [204, {}, []] }
end
