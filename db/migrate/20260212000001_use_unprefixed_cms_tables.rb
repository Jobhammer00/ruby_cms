# frozen_string_literal: true

# Ensures CMS uses unprefixed table names (preferences, content_blocks, permissions,
# user_permissions, visitor_errors). Creates tables only if they don't exist so host
# apps with existing tables are not overwritten. Adds missing columns when tables exist.
class UseUnprefixedCmsTables < ActiveRecord::Migration[7.1]
  def up
    create_preferences_if_missing
    ensure_content_blocks_table
    ensure_content_blocks_columns
    create_permissions_if_missing
    create_user_permissions_if_missing
    ensure_visitor_errors_table
    ensure_visitor_errors_columns
  end

  def down
    # No-op: leave unprefixed tables in place; host app may rely on them.
  end

  private

  def create_preferences_if_missing
    return if table_exists?(:preferences)

    create_table :preferences do |t|
      t.string :key, null: false
      t.text :value
      t.string :value_type, default: "string", null: false
      t.text :description
      t.string :category, default: "general"

      t.timestamps
    end
    add_index :preferences, :key, unique: true
    add_index :preferences, :category
  end

  def ensure_content_blocks_table
    return if table_exists?(:content_blocks)

    create_table :content_blocks do |t|
      t.string :key, null: false
      t.string :title
      t.text :content
      t.string :content_type, default: "text", null: false
      t.boolean :published, default: false, null: false
      t.string :locale, default: "en", null: false
      t.references :updated_by, null: true, foreign_key: false

      t.timestamps
    end
    add_index :content_blocks, %i[key locale], unique: true
    add_index :content_blocks, :locale
    add_index :content_blocks, %i[published content_type]
  end

  def ensure_content_blocks_columns
    return unless table_exists?(:content_blocks)

    unless column_exists?(:content_blocks, :locale)
      add_column :content_blocks, :locale, :string, default: "en", null: false
      add_index :content_blocks, :locale
      default_locale = begin
        I18n.default_locale
      rescue StandardError
        "en"
      end.to_s
      execute <<~SQL.squish
        UPDATE content_blocks SET locale = '#{default_locale}' WHERE locale IS NULL OR locale = ''
      SQL
    end

    unless column_exists?(:content_blocks, :updated_by_id)
      add_reference :content_blocks, :updated_by, null: true, foreign_key: false
      add_index :content_blocks, :updated_by_id unless index_exists?(:content_blocks, :updated_by_id)
    end

    # Replace unique index on key with key+locale if we have old index
    if index_exists?(:content_blocks, :key, unique: true) && !index_exists?(:content_blocks, %i[key locale], unique: true)
      remove_index :content_blocks, :key
      add_index :content_blocks, %i[key locale], unique: true
    end

    return if index_exists?(:content_blocks, %i[published content_type])

    add_index :content_blocks, %i[published content_type]
  end

  def create_permissions_if_missing
    return if table_exists?(:permissions)

    create_table :permissions do |t|
      t.string :key, null: false
      t.string :name

      t.timestamps
    end
    add_index :permissions, :key, unique: true
  end

  def create_user_permissions_if_missing
    return if table_exists?(:user_permissions)

    create_table :user_permissions do |t|
      t.references :user, null: false, foreign_key: false
      t.references :permission, null: false, foreign_key: false

      t.timestamps
    end
    add_index :user_permissions, %i[user_id permission_id], unique: true
  end

  def ensure_visitor_errors_table
    return if table_exists?(:visitor_errors)

    create_table :visitor_errors do |t|
      t.string :error_class, null: false
      t.text :error_message, null: false
      t.string :request_path, null: false
      t.string :request_method
      t.string :ip_address
      t.text :user_agent
      t.text :backtrace
      t.text :request_params
      t.string :session_id
      t.string :referer
      t.string :query_string
      t.boolean :resolved, default: false, null: false

      t.timestamps
    end
    add_index :visitor_errors, :created_at
    add_index :visitor_errors, :request_path
    add_index :visitor_errors, :resolved
  end

  def ensure_visitor_errors_columns
    return unless table_exists?(:visitor_errors)

    add_column :visitor_errors, :referer, :string unless column_exists?(:visitor_errors, :referer)
    return if column_exists?(:visitor_errors, :query_string)

    add_column :visitor_errors, :query_string, :string
  end
end
