import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["tab"];

  switchTab(event) {
    const tab = event.currentTarget;
    const panelId = tab.dataset.panelId;
    if (!panelId) return;

    const hideClass = "is-hidden";

    // Hide all panels
    this.tabTargets.forEach((t) => {
      const pid = t.dataset.panelId;
      if (pid) {
        const panel = document.getElementById(pid);
        if (panel) panel.classList.add(hideClass);
      }
      t.classList.remove("is-active");
    });

    // Show selected panel
    const panel = document.getElementById(panelId);
    if (panel) panel.classList.remove(hideClass);

    // Highlight selected tab
    tab.classList.add("is-active");
    tab.setAttribute("aria-selected", "true");
    this.tabTargets
      .filter((t) => t !== tab)
      .forEach((t) => t.setAttribute("aria-selected", "false"));
  }
}
