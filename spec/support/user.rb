# frozen_string_literal: true

# Minimal user model for isolated engine specs.
class User < ApplicationRecord
  self.table_name = "users"

  # Matches RubyCms::Permittable enough for controller doubles / stubs.
  def can?(_permission_key, record: nil)
    true
  end
end
