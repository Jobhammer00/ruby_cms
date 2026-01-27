import { Controller } from "@hotwired/stimulus";

// Connects to data-controller="ruby-cms--bulk-action-table"
export default class extends Controller {
  static targets = [
    "bulkBar",
    "selectedCount",
    "selectAllCheckbox",
    "itemCheckbox",
    "selectAllButton",
    "dialogOverlay",
    "dialogConfirmButton",
    "dialogContent",
  ];
  static values = {
    csrfToken: String,
    bulkActionUrl: String,
    itemName: { type: String, default: "item" },
  };

  connect() {
    this.currentAction = null;
    this.currentItemId = null;
    this.isProcessing = false;

    this.clearItemIdsFromUrl();
    this.clearSelection();

    if (this.hasSelectAllCheckboxTarget) {
      this.updateBulkBar();
    }

    // Handle ESC key to close dialog
    this.boundHandleKeydown = this.handleKeydown.bind(this);
    document.addEventListener("keydown", this.boundHandleKeydown);
  }

  disconnect() {
    if (this.boundHandleKeydown) {
      document.removeEventListener("keydown", this.boundHandleKeydown);
    }
  }

  handleKeydown(event) {
    // Close dialog on ESC key
    if (
      event.key === "Escape" &&
      this.hasDialogOverlayTarget &&
      !this.dialogOverlayTarget.classList.contains("hidden")
    ) {
      event.preventDefault();
      this.closeDialog();
    }
  }

  toggleSelectAll(event) {
    if (!this.hasSelectAllCheckboxTarget) return;

    const checked = event.target.checked;
    this.itemCheckboxTargets.forEach((checkbox) => {
      checkbox.checked = checked;
    });
    this.updateBulkBar();
  }

  selectAll() {
    if (!this.hasSelectAllCheckboxTarget) return;

    this.selectAllCheckboxTarget.checked = true;
    this.itemCheckboxTargets.forEach((checkbox) => {
      checkbox.checked = true;
    });
    this.updateBulkBar();
  }

  clearSelection() {
    if (!this.hasSelectAllCheckboxTarget) return;

    this.selectAllCheckboxTarget.checked = false;
    this.itemCheckboxTargets.forEach((checkbox) => {
      checkbox.checked = false;
    });
    this.updateBulkBar();
  }

  updateSelection() {
    this.updateBulkBar();
  }

  updateBulkBar() {
    // Find targets manually if Stimulus targets aren't available
    const controllerName = "ruby-cms--bulk-action-table";
    const bulkBar = this.hasBulkBarTarget
      ? this.bulkBarTarget
      : this.element.querySelector(`[data-${controllerName}-target="bulkBar"]`);

    const selectedCount = this.hasSelectedCountTarget
      ? this.selectedCountTarget
      : this.element.querySelector(
          `[data-${controllerName}-target="selectedCount"]`,
        );

    if (!bulkBar || !selectedCount) {
      // Silently return if targets aren't found (component might not have bulk actions)
      return;
    }

    const selectedItems = this.getSelectedIds();
    const count = selectedItems.length;

    if (count > 0) {
      bulkBar.classList.add("bulk-actions-bar--visible");
      const itemName = this.itemNameValue || "item";
      selectedCount.textContent = `${count} ${itemName}${count === 1 ? "" : "s"} selected:`;
    } else {
      bulkBar.classList.remove("bulk-actions-bar--visible");
    }

    this.updateRowHighlighting(selectedItems);

    if (this.hasSelectAllCheckboxTarget) {
      if (count === 0) {
        this.selectAllCheckboxTarget.indeterminate = false;
        this.selectAllCheckboxTarget.checked = false;
      } else if (count === this.itemCheckboxTargets.length) {
        this.selectAllCheckboxTarget.indeterminate = false;
        this.selectAllCheckboxTarget.checked = true;
      } else {
        this.selectAllCheckboxTarget.indeterminate = true;
        this.selectAllCheckboxTarget.checked = false;
      }
    }
  }

  updateRowHighlighting(selectedIds) {
    const rows = this.element.querySelectorAll("tr[data-item-id]");
    // Convert selectedIds to strings for comparison
    const selectedIdsStr = selectedIds.map((id) => String(id));

    rows.forEach((row) => {
      const itemId = String(row.getAttribute("data-item-id") || "");
      if (selectedIdsStr.includes(itemId)) {
        row.setAttribute("data-state", "selected");
      } else {
        row.removeAttribute("data-state");
      }
    });
  }

  getSelectedIds() {
    // Get checkboxes - try Stimulus targets first, then fallback to querySelector
    const controllerName = "ruby-cms--bulk-action-table";
    const checkboxes = this.hasItemCheckboxTarget
      ? this.itemCheckboxTargets
      : Array.from(
          this.element.querySelectorAll(
            `input[type="checkbox"][data-${controllerName}-target="itemCheckbox"]`,
          ),
        );

    return checkboxes
      .filter((checkbox) => checkbox.checked)
      .map((checkbox) => {
        // Try dataset.itemId first, then value, ensuring string conversion
        return String(
          checkbox.dataset.itemId ||
            checkbox.getAttribute("data-item-id") ||
            checkbox.value ||
            "",
        );
      })
      .filter((id) => id !== ""); // Remove empty IDs
  }

  showActionDialog(event) {
    const count = this.getSelectedIds().length;
    if (count === 0) {
      this.showNotification("Please select at least one item.", "error");
      return;
    }

    const actionName =
      event.params.actionName || event.currentTarget.dataset.actionName;
    const actionUrl =
      event.params.actionUrl ||
      event.currentTarget.dataset.actionUrl ||
      event.currentTarget.dataset.deleteUrl ||
      this.bulkActionUrlValue;

    if (
      event.currentTarget.dataset.actionType === "redirect" ||
      actionName === "bulk_edit"
    ) {
      this.redirectToBulkAction(actionUrl, actionName);
      return;
    }

    this.currentAction = actionName;
    this.currentActionUrl = actionUrl;

    this.showDialog();
  }

  redirectToBulkAction(url, actionName) {
    const selectedIds = this.getSelectedIds();
    if (selectedIds.length === 0) {
      this.showNotification("Please select at least one item.", "error");
      return;
    }

    const urlObj = new URL(url, window.location.origin);
    selectedIds.forEach((id) => {
      urlObj.searchParams.append("item_ids[]", id);
    });

    this.clearSelection();

    window.location.href = urlObj.toString();
  }

  showDialog() {
    if (this.hasDialogConfirmButtonTarget) {
      this.dialogConfirmButtonTarget.disabled = false;
    }

    // Show the dialog overlay
    if (this.hasDialogOverlayTarget) {
      this.dialogOverlayTarget.classList.remove("hidden");
      // Prevent body scroll
      document.body.classList.add("overflow-hidden");
      // Focus the dialog for accessibility
      if (this.hasDialogContentTarget) {
        this.dialogContentTarget.focus();
      }
    }
  }

  closeDialog() {
    // Hide the dialog overlay
    if (this.hasDialogOverlayTarget) {
      this.dialogOverlayTarget.classList.add("hidden");
      // Allow body scroll
      document.body.classList.remove("overflow-hidden");
    }
    this.currentAction = null;
    this.currentItemId = null;
    this.isProcessing = false;
  }

  stopPropagation(event) {
    event.stopPropagation();
  }

  async showIndividualDeleteDialog(event) {
    const deleteButton = event.currentTarget;
    const requireConfirm = deleteButton.dataset.requireConfirm !== "false";

    if (!requireConfirm) {
      const itemId =
        event.params.itemId || event.params.rubyCmsBulkActionTableItemIdParam;

      if (!itemId) {
        this.showNotification("Item ID not found for deletion.", "error");
        return;
      }

      if (this.isProcessing) {
        event?.preventDefault();
        event?.stopPropagation();
        return;
      }

      this.isProcessing = true;

      try {
        const deletePath =
          deleteButton.dataset.deletePath ||
          this.getFallbackPath(this.itemNameValue, itemId);

        if (!deletePath) {
          this.showNotification("Delete path not found.", "error");
          return;
        }

        await this.performBulkAction(null, "delete", deletePath, [itemId]);
      } finally {
        this.isProcessing = false;
      }
      return;
    }

    const itemId =
      event.params.itemId || event.params.rubyCmsBulkActionTableItemIdParam;

    const deletePath =
      deleteButton.dataset.deletePath ||
      this.getFallbackPath(this.itemNameValue, itemId);

    this.currentAction = "delete";
    this.currentItemId = itemId;
    this.currentActionUrl = deletePath;

    this.showDialog();
  }

  getFallbackPath(itemName, itemId) {
    if (
      !itemId ||
      itemId === "" ||
      itemId === "undefined" ||
      itemId === "null"
    ) {
      return null;
    }
    const routeName = itemName
      .toLowerCase()
      .replace(/\s+/g, "_")
      .replace(/_+/g, "_");
    const pluralName = routeName.endsWith("s") ? routeName : `${routeName}s`;
    return `/admin/${pluralName}/${itemId}`;
  }

  async confirmAction(event) {
    if (this.isProcessing) {
      event?.preventDefault();
      event?.stopPropagation();
      return;
    }

    this.isProcessing = true;

    if (this.hasDialogConfirmButtonTarget) {
      this.dialogConfirmButtonTarget.disabled = true;
      this.dialogConfirmButtonTarget.textContent = "Processing...";
    }

    try {
      if (this.currentAction) {
        const actionUrl =
          this.currentActionUrl ||
          event?.currentTarget?.dataset?.actionUrl ||
          event?.currentTarget?.dataset?.deleteUrl ||
          this.bulkActionUrlValue;

        const itemIds = this.currentItemId
          ? [this.currentItemId]
          : this.getSelectedIds();

        await this.performBulkAction(
          event,
          this.currentAction,
          actionUrl,
          itemIds,
        );
      }
    } finally {
      this.isProcessing = false;
      this.currentAction = null;
      this.currentItemId = null;
      this.currentActionUrl = null;
      this.closeDialog();
    }
  }

  async performBulkAction(
    event = null,
    actionName = null,
    customUrl = null,
    itemIds = null,
  ) {
    const selectedIds = itemIds || this.getSelectedIds();

    if (selectedIds.length === 0) {
      this.showNotification("Please select at least one item.", "error");
      return;
    }

    const action =
      actionName ||
      event?.currentTarget?.dataset?.actionName ||
      this.currentAction ||
      "delete";

    const actionUrl =
      customUrl ||
      event?.currentTarget?.dataset?.actionUrl ||
      event?.currentTarget?.dataset?.deleteUrl ||
      this.currentActionUrl ||
      this.bulkActionUrlValue;

    if (!actionUrl) {
      this.showNotification(
        "Action URL not configured. Please configure an action URL for this page.",
        "error",
      );
      return;
    }

    try {
      const method =
        actionUrl.includes("bulk_delete") ||
        action === "delete" ||
        actionUrl.match(/\/\d+\/?$/)
          ? "DELETE"
          : "PATCH";

      const response = await fetch(actionUrl, {
        method: method,
        headers: {
          "X-CSRF-Token":
            this.csrfTokenValue ||
            document.querySelector('meta[name="csrf-token"]').content,
          "Content-Type": "application/json",
          Accept: "application/json",
        },
        body: JSON.stringify({
          item_ids: selectedIds,
        }),
      });

      if (response.ok) {
        this.clearSelection();
        this.clearItemIdsFromUrl();

        if (window.Turbo) {
          const turboFrame = document.getElementById("admin_table_content");
          if (turboFrame) {
            turboFrame.src = window.location.href;
          } else {
            window.Turbo.visit(window.location.href);
          }
        } else {
          window.location.reload();
        }
      } else {
        const contentType = response.headers.get("content-type");
        let errorMessage = `An error occurred while performing ${action}.`;

        if (contentType && contentType.includes("application/json")) {
          try {
            const error = await response.json();
            errorMessage = error.error || error.message || errorMessage;
          } catch (e) {
            const errorText = await response.text();
            if (errorText && !errorText.includes("<!DOCTYPE")) {
              errorMessage = errorText;
            }
          }
        } else {
          const errorText = await response.text();
          if (errorText.includes("<!DOCTYPE")) {
            errorMessage = `Server error occurred during ${action}. Please try again or refresh the page.`;
          } else {
            errorMessage = errorText.substring(0, 200);
          }
        }
        this.showNotification(errorMessage, "error");
      }
    } catch (error) {
      console.error(`Error performing bulk action ${action}:`, error);
      this.showNotification(
        `An error occurred while performing ${action}.`,
        "error",
      );
    }
  }

  showNotification(message, type = "info") {
    const toast = document.createElement("div");
    toast.className = `fixed top-4 right-4 z-50 px-4 py-2 rounded-md shadow-lg text-white max-w-sm ${
      type === "success"
        ? "bg-green-600"
        : type === "error"
          ? "bg-red-600"
          : "bg-blue-600"
    }`;
    toast.textContent = message;

    document.body.appendChild(toast);

    setTimeout(() => {
      toast.remove();
    }, 5000);
  }

  clearItemIdsFromUrl() {
    const url = new URL(window.location);
    const hasItemIds =
      url.searchParams.has("item_ids[]") ||
      Array.from(url.searchParams.keys()).some((key) =>
        key.startsWith("item_ids"),
      );

    if (hasItemIds) {
      url.searchParams.delete("item_ids[]");
      Array.from(url.searchParams.keys())
        .filter((key) => key.startsWith("item_ids"))
        .forEach((key) => url.searchParams.delete(key));

      window.history.replaceState({}, "", url.toString());
    }
  }
}
