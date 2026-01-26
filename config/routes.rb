# frozen_string_literal: true

RubyCms::Engine.routes.draw do
  get "p/:key", to: "ruby_cms/public/pages#show", as: :public_page, constraints: { key: /[\w-]+/ }

  scope path: "admin", module: "ruby_cms/admin", as: "ruby_cms_admin" do
    root to: "dashboard#index"
    resources :content_blocks
    resources :pages do
      member do
        get "builder", to: "page_builder#show", as: :builder
        patch "builder", to: "page_builder#update"
      end
    end

    # Standalone page builder routes
    get "page_builder", to: "page_builder#index", as: :page_builder
    scope "page_builder" do
      post "regions", to: "page_builder#create_region", as: :page_builder_regions
      post "nodes", to: "page_builder#create_node", as: :page_builder_nodes
      get "nodes/:id", to: "page_builder#show_node", as: :page_builder_node_show
      patch "nodes/:id", to: "page_builder#update_node", as: :page_builder_node
      delete "nodes/:id", to: "page_builder#destroy_node", as: :page_builder_node_delete
      post "nodes/reorder", to: "page_builder#reorder_nodes", as: :page_builder_nodes_reorder
      get "component_schema", to: "page_builder#component_schema", as: :page_builder_component_schema
    end
    resources :navigation_menus do
      resources :navigation_items, except: [:index]
      post "navigation_items/reorder", to: "navigation_items#reorder", as: :navigation_items_reorder
    end
    resources :permissions, only: %i[index]
    resources :users, only: %i[index] do
      resources :permissions, only: %i[index create destroy], controller: "user_permissions", path: "permissions"
    end

    get "editor", to: "editor#index", as: :editor
    get "editor/preview", to: "editor#preview", as: :editor_preview
    post "editor/bulk", to: "editor#bulk", as: :editor_bulk

    patch "locale", to: "locale#update", as: :locale
  end
end
