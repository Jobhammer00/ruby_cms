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
    const isOpen = this.hasSidebarTarget && this.sidebarTarget.classList.contains("translate-x-0")
    isOpen ? this.close() : this.open()
  }

  close() {
    if (this.hasSidebarTarget) {
      this.sidebarTarget.classList.remove("translate-x-0")
      this.sidebarTarget.classList.add("-translate-x-full")
    }
    if (this.hasOverlayTarget) {
      this.overlayTarget.classList.add("hidden")
    }
  }

  open() {
    if (this.hasSidebarTarget) {
      this.sidebarTarget.classList.remove("-translate-x-full")
      this.sidebarTarget.classList.add("translate-x-0")
    }
    if (this.hasOverlayTarget) {
      this.overlayTarget.classList.remove("hidden")
    }
  }

  handleOutsideClick(event) {
    if (!this.hasSidebarTarget || !this.sidebarTarget.classList.contains("translate-x-0")) {
      return
    }

    // Don't close if clicking inside sidebar or toggle button
    if (this.sidebarTarget.contains(event.target) || this.element.contains(event.target)) {
      return
    }

    this.close()
  }
}
