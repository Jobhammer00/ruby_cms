# frozen_string_literal: true

module RubyCms
  # Backwards-compatible shim: keep RubyCms::ContentBlock working,
  # but the canonical model is the top-level ::ContentBlock.
  class ContentBlock < ::ContentBlock
  end
end
