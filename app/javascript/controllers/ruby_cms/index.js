// RubyCms Stimulus Controllers
// This file exports all controllers for registration in the host application

import PageBuilderController from "ruby_cms/page_builder_controller"
import VisualEditorController from "ruby_cms/visual_editor_controller"
import MobileMenuController from "ruby_cms/mobile_menu_controller"
import FlashMessagesController from "ruby_cms/flash_messages_controller"
import NavigationItemFormController from "ruby_cms/navigation_item_form_controller"
import BulkActionTableController from "ruby_cms/bulk_action_table_controller"
import PagePreviewController from "ruby_cms/page_preview_controller"

export {
  PageBuilderController,
  VisualEditorController,
  MobileMenuController,
  FlashMessagesController,
  NavigationItemFormController,
  BulkActionTableController,
  PagePreviewController
}

// Helper function to register all RubyCms controllers with a Stimulus application
export function registerRubyCmsControllers(application) {
  application.register("ruby-cms--page-builder", PageBuilderController)
  application.register("ruby-cms--visual-editor", VisualEditorController)
  application.register("ruby-cms--mobile-menu", MobileMenuController)
  application.register("ruby-cms--flash-messages", FlashMessagesController)
  application.register("ruby-cms--navigation-item-form", NavigationItemFormController)
  application.register("ruby-cms--bulk-action-table", BulkActionTableController)
  application.register("ruby-cms--page-preview", PagePreviewController)
}
