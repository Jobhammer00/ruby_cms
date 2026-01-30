// RubyCms Stimulus Controllers
// This file exports all controllers for registration in the host application

import VisualEditorController from "ruby_cms/visual_editor_controller";
import VisualEditorHeaderController from "ruby_cms/visual_editor_header_controller";
import PagePreviewController from "ruby_cms/page_preview_controller";
import MobileMenuController from "ruby_cms/mobile_menu_controller";
import FlashMessagesController from "ruby_cms/flash_messages_controller";
import BulkActionTableController from "ruby_cms/bulk_action_table_controller";
import ToggleController from "ruby_cms/toggle_controller";
import LocaleTabsController from "ruby_cms/locale_tabs_controller";
import ClickableRowController from "ruby_cms/clickable_row_controller";
import AutoSavePreferenceController from "ruby_cms/auto_save_preference_controller";

export {
  VisualEditorController,
  VisualEditorHeaderController,
  PagePreviewController,
  MobileMenuController,
  FlashMessagesController,
  BulkActionTableController,
  ToggleController,
  LocaleTabsController,
  ClickableRowController,
  AutoSavePreferenceController,
};

// Helper function to register all RubyCms controllers with a Stimulus application
export function registerRubyCmsControllers(application) {
  application.register("ruby-cms--visual-editor", VisualEditorController);
  application.register(
    "ruby-cms--visual-editor-header",
    VisualEditorHeaderController,
  );
  application.register("ruby-cms--page-preview", PagePreviewController);
  application.register("ruby-cms--mobile-menu", MobileMenuController);
  application.register("ruby-cms--flash-messages", FlashMessagesController);
  application.register(
    "ruby-cms--bulk-action-table",
    BulkActionTableController,
  );
  application.register("ruby-cms--toggle", ToggleController);
  application.register("ruby-cms--locale-tabs", LocaleTabsController);
  application.register("clickable-row", ClickableRowController);
  application.register(
    "ruby-cms--auto-save-preference",
    AutoSavePreferenceController,
  );
}

// Auto-register controllers when this module is imported
// Works with Rails 7+ importmap setup where Stimulus is loaded via @hotwired/stimulus
if (typeof window !== "undefined") {
  let registered = false;

  const registerControllers = (app) => {
    if (registered || !app || typeof app.register !== "function") return false;
    registerRubyCmsControllers(app);
    registered = true;
    return true;
  };

  // Try to get Stimulus from the standard Rails 7+ location
  const tryRegister = () => {
    // Check window.Stimulus (standard Rails 7+ pattern with @hotwired/stimulus-loading)
    if (window.Stimulus) {
      return registerControllers(window.Stimulus);
    }
    // Fallback: check for application export
    if (window.application) {
      return registerControllers(window.application);
    }
    return false;
  };

  // Try immediately
  if (!tryRegister()) {
    // Wait for turbo:load which fires after Stimulus is initialized
    const onTurboLoad = () => {
      if (tryRegister()) {
        document.removeEventListener("turbo:load", onTurboLoad);
      }
    };
    document.addEventListener("turbo:load", onTurboLoad);

    // Also try on DOMContentLoaded as fallback
    const onDOMReady = () => {
      setTimeout(() => {
        if (tryRegister()) {
          document.removeEventListener("DOMContentLoaded", onDOMReady);
        }
      }, 50);
    };

    if (document.readyState === "loading") {
      document.addEventListener("DOMContentLoaded", onDOMReady);
    } else {
      // DOM already loaded, try after a short delay
      setTimeout(tryRegister, 50);
      setTimeout(tryRegister, 200);
      setTimeout(tryRegister, 500);
    }
  }
}
