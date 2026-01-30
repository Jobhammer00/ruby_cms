import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="clickable-row"
export default class extends Controller {
  static values = {
    clickUrl: String
  }

  navigate(event) {
    // Don't navigate if clicking on a checkbox, button, or link
    const target = event.target
    if (
      target.matches('input[type="checkbox"]') ||
      target.closest('input[type="checkbox"]') ||
      target.matches('button') ||
      target.closest('button') ||
      target.matches('a') ||
      target.closest('a')
    ) {
      return
    }

    // Navigate to the URL
    if (this.clickUrlValue) {
      window.location.href = this.clickUrlValue
    }
  }
}
