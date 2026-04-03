import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["tab", "localeLabel"];

  connect() {
    const activeTab = this.tabTargets.find(
      (t) => t.getAttribute("aria-selected") === "true"
    );
    if (!activeTab) return;

    this.tabTargets.forEach((t) => {
      this.setTabState(t, t === activeTab);
    });
    this.syncLocaleLabel(activeTab);
  }

  switchTab(event) {
    const tab = event.currentTarget;
    const panelId = tab.dataset.panelId;
    if (!panelId) return;

    const hideClasses = ["hidden", "is-hidden"];
    const panels = this.element.querySelectorAll("[data-locale-panel]");

    // Hide all panels in this tabs component
    panels.forEach((panel) => panel.classList.add(...hideClasses));

    // Reset all tab states
    this.tabTargets.forEach((t) => {
      this.setTabState(t, false);
    });

    // Show selected panel
    const panel = this.findPanel(panelId);
    if (panel) panel.classList.remove(...hideClasses);

    // Highlight selected tab
    this.setTabState(tab, true);
    this.syncLocaleLabel(tab);
  }

  findPanel(panelId) {
    // Scope lookup to this component first so multiple tab groups never conflict.
    if (window.CSS && typeof window.CSS.escape === "function") {
      const scoped = this.element.querySelector(`#${window.CSS.escape(panelId)}`);
      if (scoped) return scoped;
    }
    return document.getElementById(panelId);
  }

  setTabState(tab, isActive) {
    const activeClasses = this.splitClasses(tab.dataset.activeClasses);
    const inactiveClasses = this.splitClasses(tab.dataset.inactiveClasses);

    // Remove both sets first, then apply the desired one.
    tab.classList.remove(...activeClasses, ...inactiveClasses, "is-active");
    tab.classList.add(...(isActive ? activeClasses : inactiveClasses));
    if (isActive) tab.classList.add("is-active");
    tab.setAttribute("aria-selected", isActive ? "true" : "false");
  }

  syncLocaleLabel(tab) {
    if (!this.hasLocaleLabelTarget) return;

    const label = tab.dataset.localeLabel;
    if (label) this.localeLabelTarget.textContent = label;
  }

  splitClasses(classListString) {
    return (classListString || "")
      .split(" ")
      .map((klass) => klass.trim())
      .filter(Boolean);
  }
}
