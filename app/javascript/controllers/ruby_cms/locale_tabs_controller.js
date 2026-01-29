import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["tab"];

  switchTab(event) {
    const tab = event.currentTarget;
    const panelId = tab.dataset.panelId;
    if (!panelId) return;

    // Hide all panels
    this.tabTargets.forEach((t) => {
      const pid = t.dataset.panelId;
      if (pid) {
        const panel = document.getElementById(pid);
        if (panel) panel.classList.add("hidden");
      }
      t.classList.remove(
        "bg-white",
        "border-b-2",
        "border-blue-500",
        "text-blue-600",
      );
      t.classList.add("text-gray-600");
    });

    // Show selected panel
    const panel = document.getElementById(panelId);
    if (panel) panel.classList.remove("hidden");

    // Highlight selected tab
    tab.classList.add(
      "bg-white",
      "border-b-2",
      "border-blue-500",
      "text-blue-600",
    );
    tab.classList.remove("text-gray-600");
    tab.setAttribute("aria-selected", "true");
    this.tabTargets
      .filter((t) => t !== tab)
      .forEach((t) => t.setAttribute("aria-selected", "false"));
  }
}
