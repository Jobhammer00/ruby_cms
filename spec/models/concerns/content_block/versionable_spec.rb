# frozen_string_literal: true

require "rails_helper"

RSpec.describe ContentBlock::Versionable do
  # Versie wordt aangemaakt bij ContentBlock.create!
  # Versie wordt aangemaakt bij content_block.update!
  # Geen versie bij niet-inhoudelijke wijzigingen
  # Correct event type: "create", "update", "publish", "unpublish"
  # version_number auto-increment per content_block
  # Visual editor pad: versie via save
  # Multi-locale update: elke locale-variant eigen versie
  # rollback_to_version! herstelt alle velden
  # Rich content HTML wordt correct gesnapshot
end
