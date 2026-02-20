import { Controller } from "@hotwired/stimulus";

// Auto-saves preference changes via JSON PATCH.
export default class extends Controller {
  static values = {
    preferenceKey: String,
    settingsUrl: String,
    tab: String,
  };

  async save(event) {
    const target = event.target;
    const value = target.type === "checkbox" ? target.checked : target.value;
    const key = this.preferenceKeyValue;
    const url = this.settingsUrlValue || "/admin/settings";

    if (!key) {
      console.error("Preference key not found");
      return;
    }

    try {
      const csrf = document.querySelector('meta[name="csrf-token"]');
      const response = await fetch(url, {
        method: "PATCH",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": csrf ? csrf.content : "",
          Accept: "application/json",
        },
        body: JSON.stringify({
          key,
          value,
          tab: this.tabValue || null,
        }),
      });

      if (!response.ok) {
        this.showNotification(`Failed to save ${key}`, "error");
        return;
      }

      const payload = await response.json();
      const updatedKey = (payload.updated_keys && payload.updated_keys[0]) || key;
      const displayName = updatedKey
        .replace(/^nav_show_/, "")
        .replace(/_per_page$/, "")
        .replace(/_/g, " ");

      this.showNotification(`Saved: ${displayName}`, "success");
    } catch (error) {
      console.error("Error saving preference:", error);
      this.showNotification(`Error saving ${key}`, "error");
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
    }, 3000);
  }
}
