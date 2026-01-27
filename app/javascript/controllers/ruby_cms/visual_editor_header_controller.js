import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["pageSelector", "editModeToggle", "editModeText"]
  
  static values = {
    currentPage: String
  }

  connect() {
    // Enable edit mode by default (matching backend default)
    this.editModeEnabled = true
    
    // Update UI to reflect enabled state
    if (this.hasEditModeTextTarget) {
      this.editModeTextTarget.textContent = "Exit Edit Mode"
    }
    if (this.hasEditModeToggleTarget) {
      this.editModeToggleTarget.style.backgroundColor = "rgb(29 78 216)"
      this.editModeToggleTarget.style.color = "white"
    }
  }

  changePage(event) {
    const selectedPage = event.target.value
    window.location.href = `/admin/visual_editor?page=${selectedPage}`
  }

  toggleEditMode() {
    this.editModeEnabled = !this.editModeEnabled
    
    // Update button text
    if (this.hasEditModeTextTarget) {
      this.editModeTextTarget.textContent = this.editModeEnabled ? "Exit Edit Mode" : "Edit Mode"
    }
    
    // Update button style
    if (this.hasEditModeToggleTarget) {
      if (this.editModeEnabled) {
        this.editModeToggleTarget.style.backgroundColor = "rgb(29 78 216)"
        this.editModeToggleTarget.style.color = "white"
      } else {
        this.editModeToggleTarget.style.backgroundColor = "rgb(219 234 254)"
        this.editModeToggleTarget.style.color = "rgb(29 78 216)"
      }
    }
    
    // Send message to visual editor controller
    this.dispatch("editModeChanged", { 
      detail: { enabled: this.editModeEnabled },
      bubbles: true
    })
    
    // Update preview iframe URL
    const iframe = document.querySelector('[data-ruby-cms--visual-editor-target="previewFrame"]')
    if (iframe) {
      const url = new URL(iframe.src)
      url.searchParams.set("edit_mode", this.editModeEnabled)
      iframe.src = url.toString()
    }
  }

  refresh() {
    // Refresh the preview iframe
    const iframe = document.querySelector('[data-ruby-cms--visual-editor-target="previewFrame"]')
    if (iframe) {
      iframe.src = iframe.src
    }
  }
}
