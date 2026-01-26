# frozen_string_literal: true

class CreateRubyCmsSections < ActiveRecord::Migration[7.1]
  def json_type
    connection.adapter_name.to_s.downcase.include?("postgres") ? :jsonb : :json
  end

  def change
    create_table :ruby_cms_sections do |t|
      t.string :key, null: false
      t.string :name, null: false
      t.text :description
      t.public_send(json_type, :region_data, default: {}, null: false) # Stores regions and nodes structure
      t.integer :position, default: 0, null: false
      t.boolean :published, default: true, null: false
      t.timestamps
    end

    add_index :ruby_cms_sections, :key, unique: true
    add_index :ruby_cms_sections, :published
    add_index :ruby_cms_sections, :position
  end
end
