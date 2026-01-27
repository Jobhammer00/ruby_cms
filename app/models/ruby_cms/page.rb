# frozen_string_literal: true

module RubyCms
  class Page < ::ApplicationRecord
    self.table_name = "ruby_cms_pages"

    RENDER_MODES = %w[builder html template].freeze

    validates :key, presence: true, uniqueness: true
    validates :key,
              format: {
                with: /\A[\w-]+\z/,
                message: "only letters, numbers, hyphens, and underscores"
              }
    validates :render_mode, presence: true, inclusion: { in: RENDER_MODES }
    validates :template_path, presence: true, if: -> { render_mode == "template" }
    validates :body_html, presence: true, if: -> { render_mode == "html" }

    scope :published, -> { where(published: true) }
    scope :drafts, -> { where(draft: true) }
    scope :published_only, -> { where(published: true, draft: false) }
    scope :by_position, -> { order(:position, :key) }

    has_many :page_regions, class_name: "RubyCms::PageRegion", dependent: :destroy
    has_many :page_versions, class_name: "RubyCms::PageVersion", dependent: :destroy

    before_validation :set_default_render_mode, on: :create
    after_commit :enqueue_compile, if: :should_compile?

    # Check if compiled HTML is fresh (matches current cache key)
    def compiled_html_fresh?
      return false unless compiled_html.present? && compiled_at.present?
      return false unless builder_mode? || html_mode?

      # Check if compiled_at matches updated_at (within 1 second tolerance)
      (compiled_at - updated_at).abs < 1.second
    end

    # Merge of config.preview_templates and Page records. Page records override config for same key.
    def self.preview_templates_hash
      config = begin
        Rails.application.config.ruby_cms.preview_templates
      rescue StandardError
        nil
      end || {}
      pages = by_position.pluck(:key, :template_path).to_h
      config.merge(pages)
    end

    # All page keys for editor select: config keys + Page keys, uniq.
    def self.all_page_keys
      config = begin
        Rails.application.config.ruby_cms.preview_templates
      rescue StandardError
        nil
      end || {}
      (config.keys + pluck(:key)).uniq.sort
    end

    # Check if this page uses the builder (has regions/nodes)
    def built_with_builder?
      page_regions.any?
    end

    # Get or create a region by key
    def region(key)
      page_regions.find_or_create_by(key:) do |region|
        region.position = page_regions.count
      end
    end

    # Check if page uses builder mode
    def builder_mode?
      render_mode == "builder"
    end

    # Check if page uses HTML mode
    def html_mode?
      render_mode == "html"
    end

    # Check if page uses template mode
    def template_mode?
      render_mode == "template"
    end

    # Get layout to use (page.layout or config default)
    def effective_layout
      layout.presence || begin
        Rails.application.config.ruby_cms.public_page_layout
      rescue StandardError
        nil
      end || "application"
    end

    # Enqueue compilation job (public so it can be called from callbacks)
    def enqueue_compile
      return unless should_compile?

      # Only compile if published and not a draft
      return unless published? && !draft?

      # Use perform_later to avoid blocking
      RubyCms::CompilePageJob.perform_later(id)
    end

    # Save current state as a version
    # @param user [User] User creating the version
    # @param notes [String] Optional notes about this version
    # @return [RubyCms::PageVersion] Created version
    def save_version(user: nil, notes: nil)
      version_number = (page_versions.maximum(:version_number) || 0) + 1

      region_snapshot = if builder_mode?
                          serialize_regions
                        else
                          {}
                        end

      page_versions.create!(
        title: title,
        body_html: body_html,
        layout: layout,
        render_mode: render_mode,
        region_snapshot: region_snapshot,
        version_number: version_number,
        created_by: user,
        notes: notes
      )
    end

    # Publish the page (remove draft status)
    # @param user [User] User publishing the page
    # @return [Boolean] Success
    def publish!(user: nil)
      transaction do
        # Save version before publishing if there are changes
        save_version(user: user, notes: "Published") if changed? || page_regions.any? do |r|
          r.changed?
        end

        self.draft = false
        self.published = true
        save!
      end
    end

    # Save as draft
    # @return [Boolean] Success
    def save_draft!
      self.draft = true
      save!
    end

    # Restore page from a version
    # @param version [RubyCms::PageVersion] Version to restore
    # @param user [User] User restoring the version
    # @return [Boolean] Success
    def restore_from_version!(version, user: nil)
      transaction do
        # Save current state as version before restoring
        save_version(user: user, notes: "Before restoring version #{version.version_number}")

        self.title = version.title
        self.body_html = version.body_html
        self.layout = version.layout
        self.render_mode = version.render_mode

        # Restore regions if builder mode
        if builder_mode? && version.region_snapshot.present?
          restore_regions_from_snapshot(version.region_snapshot)
        end

        save!
      end
    end

    private

    def serialize_regions
      page_regions.includes(page_nodes: :children).by_position.each_with_object({}) do |region, hash|
        hash[region.key] = {
          nodes: region.page_nodes.root_nodes.by_position.map do |node|
            serialize_node(node)
          end
        }
      end
    end

    def serialize_node(node)
      data = {
        component_key: node.component_key,
        props: node.props || {},
        depth: node.depth || 0
      }

      if node.children.any?
        data[:children] = node.children.by_position.map {|child| serialize_node(child) }
      end

      data
    end

    def restore_regions_from_snapshot(snapshot)
      # Clear existing regions
      page_regions.destroy_all

      # Recreate regions from snapshot
      snapshot.each do |region_key, region_data|
        next unless region_data.kind_of?(Hash)

        region = page_regions.create!(key: region_key, position: page_regions.count)

        next unless region_data[:nodes].kind_of?(Array)

        region_data[:nodes].each_with_index do |node_data, index|
          next unless node_data.kind_of?(Hash)

          node = region.page_nodes.create!(
            component_key: node_data[:component_key],
            props: node_data[:props] || {},
            position: index,
            depth: node_data[:depth] || 0
          )

          # Restore nested children
          if node_data[:children].kind_of?(Array)
            restore_nested_nodes(node, node_data[:children], 1)
          end
        end
      end
    end

    def restore_nested_nodes(parent_node, children_data, current_depth)
      children_data.each_with_index do |child_data, index|
        next unless child_data.kind_of?(Hash)

        child = parent_node.children.create!(
          component_key: child_data[:component_key],
          props: child_data[:props] || {},
          position: index,
          depth: current_depth
        )

        if child_data[:children].kind_of?(Array)
          restore_nested_nodes(child, child_data[:children], current_depth + 1)
        end
      end
    end

    def set_default_render_mode
      self.render_mode ||= "builder"
    end

    def should_compile?
      (builder_mode? || html_mode?) && (published? || saved_change_to_published?) && !draft?
    end
  end
end
