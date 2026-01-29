# frozen_string_literal: true

class AddLocaleToRubyCmsContentBlocks < ActiveRecord::Migration[7.1]
  def change # rubocop:disable Metrics/MethodLength
    add_column :ruby_cms_content_blocks, :locale, :string, default: "en", null: false

    # Remove old unique index on key
    remove_index :ruby_cms_content_blocks, :key if index_exists?(:ruby_cms_content_blocks, :key)

    # Add new composite unique index on key + locale
    add_index :ruby_cms_content_blocks, %i[key locale], unique: true

    # Add index for locale queries
    add_index :ruby_cms_content_blocks, :locale

    # Migrate existing records to default locale
    # This ensures existing content blocks get the default locale
    # Use execute to avoid model loading issues during migration
    reversible do |dir|
      dir.up do
        default_locale = begin
          I18n.default_locale.to_s
        rescue StandardError
          "en"
        end
        execute <<~SQL.squish
          UPDATE ruby_cms_content_blocks
          SET locale = '#{default_locale}'
          WHERE locale IS NULL OR locale = ''
        SQL
      end
    end
  end
end
