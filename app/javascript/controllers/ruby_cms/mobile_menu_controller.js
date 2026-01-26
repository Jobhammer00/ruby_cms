import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="ruby-cms--mobile-menu"
export default class extends Controller {
  static targets = ["sidebar", "overlay"]

  connect() {
    // Close menu when clicking outside (only on mobile)
    if (window.innerWidth < 1024) {
      document.addEventListener("click", this.handleOutsideClick.bind(this))
    }
  }

  disconnect() {
    document.removeEventListener("click", this.handleOutsideClick.bind(this))
  }

  toggle() {
    if (this.hasSidebarTarget) {
      this.sidebarTarget.classList.toggle("open")
    }
    if (this.hasOverlayTarget) {
      this.overlayTarget.classList.toggle("show")
    }
  }

  close() {
    if (this.hasSidebarTarget) {
      this.sidebarTarget.classList.remove("open")
    }
    if (this.hasOverlayTarget) {
      this.overlayTarget.classList.remove("show")
    }
  }

  handleOutsideClick(event) {
    if (!this.hasSidebarTarget || !this.sidebarTarget.classList.contains("open")) {
      return
    }

    // Don't close if clicking inside sidebar or toggle button
    if (this.sidebarTarget.contains(event.target) || this.element.contains(event.target)) {
      return
    }

    this.close()
  }
}
