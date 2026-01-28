# frozen_string_literal: true

RubyCms::Engine.routes.draw do
  scope path: "admin", module: "ruby_cms/admin", as: "ruby_cms_admin" do
    root to: "dashboard#index"
    resources :content_blocks do
      collection do
        delete "bulk_delete", to: "content_blocks#bulk_delete"
        patch "bulk_publish", to: "content_blocks#bulk_publish"
        patch "bulk_unpublish", to: "content_blocks#bulk_unpublish"
      end
    end

    resources :permissions, only: %i[index create destroy] do
      collection do
        delete "bulk_delete", to: "permissions#bulk_delete"
      end
    end
    resources :users, only: %i[index create destroy] do
      collection do
        delete "bulk_delete", to: "users#bulk_delete"
      end
      resources :permissions, only: %i[index create destroy], controller: "user_permissions",
                              path: "permissions" do
        collection do
          delete "bulk_delete", to: "user_permissions#bulk_delete"
        end
      end
    end

    # Visual editor routes
    get "visual_editor", to: "visual_editor#index", as: :visual_editor
    get "visual_editor/page_preview", to: "visual_editor#page_preview",
                                      as: :visual_editor_page_preview
    patch "visual_editor/quick_update", to: "visual_editor#quick_update",
                                        as: :visual_editor_quick_update

    patch "locale", to: "locale#update", as: :locale
  end
end
