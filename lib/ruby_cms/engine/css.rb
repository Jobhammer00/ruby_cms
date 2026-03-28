# frozen_string_literal: true

module RubyCms
  module EngineCss
    def compile_admin_css(dest_path)
      gem_root = begin
        root
      rescue StandardError
        Pathname.new(File.expand_path("../..", __dir__))
      end
      RubyCms::CssCompiler.compile(gem_root, dest_path)
    end
  end
end
