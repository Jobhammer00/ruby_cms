import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="ruby-cms--bulk-action-table"
export default class extends Controller {
  static targets = [
    "selectAll",
    "itemCheckbox",
    "selectionCount"
  ]

  connect() {
    this.updateSelectionCount()
    
    if (this.hasSelectAllTarget) {
      this.selectAllTarget.addEventListener('change', (e) => {
        this.itemCheckboxTargets.forEach(checkbox => {
          checkbox.checked = e.target.checked
        })
        this.updateSelectionCount()
      })
    }
    
    this.itemCheckboxTargets.forEach(checkbox => {
      checkbox.addEventListener('change', () => this.updateSelectionCount())
    })
  }

  updateSelectionCount() {
    const count = this.itemCheckboxTargets.filter(cb => cb.checked).length
    if (this.hasSelectionCountTarget) {
      this.selectionCountTarget.textContent = count ? `${count} selected` : ""
    }
  }
}
