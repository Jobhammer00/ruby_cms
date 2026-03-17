import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="ruby-cms--flash-messages"
export default class extends Controller {
  static targets = ["message"]

  connect() {
    // Auto-dismiss flash messages after 5 seconds
    this.messageTargets.forEach((message) => {
      setTimeout(() => {
        this.dismissMessage(message)
      }, 5000)
    })
  }

  dismiss(event) {
    const message = event.currentTarget.closest(".flash-message")
    if (message) {
      this.dismissMessage(message)
    }
  }

  dismissMessage(message) {
    message.classList.add("opacity-0", "-translate-y-1")
    setTimeout(() => {
      message.remove()
    }, 200)
  }
}
