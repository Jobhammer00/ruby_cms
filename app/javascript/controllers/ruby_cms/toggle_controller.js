// Toggle visibility controller for simple show/hide functionality
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["toggleable"]

  toggle(event) {
    event.preventDefault()
    const targetId = event.currentTarget.dataset.toggleTargetId
    if (targetId) {
      const element = document.getElementById(targetId)
      if (element) {
        element.classList.toggle("hidden")
      }
    }
  }

  hide(event) {
    event.preventDefault()
    const targetId = event.currentTarget.dataset.toggleTargetId
    if (targetId) {
      const element = document.getElementById(targetId)
      if (element) {
        element.classList.add("hidden")
      }
    }
  }

  show(event) {
    event.preventDefault()
    const targetId = event.currentTarget.dataset.toggleTargetId
    if (targetId) {
      const element = document.getElementById(targetId)
      if (element) {
        element.classList.remove("hidden")
      }
    }
  }
}
