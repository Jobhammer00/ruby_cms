import { Controller } from "@hotwired/stimulus";

// Auto-saves preference changes via AJAX
export default class extends Controller {
  static values = {
    preferenceKey: String,
  };

  async save(event) {
    const target = event.target;
    const value = target.type === "checkbox" ? target.checked : target.value;
    const key = this.preferenceKeyValue;

    if (!key) {
      console.error("Preference key not found");
      return;
    }

    try {
      const response = await fetch("/admin/settings", {
        method: "PATCH",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')
            .content,
          Accept: "application/json",
        },
        body: JSON.stringify({ key, value }),
      });

      if (response.ok) {
        const displayName = key
          .replace(/^nav_show_/, "")
          .replace(/_per_page$/, "")
          .replace(/_/g, " ");
        this.showNotification(`Saved: ${displayName}`, "success");
      } else {
        this.showNotification(`Failed to save ${key}`, "error");
      }
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
