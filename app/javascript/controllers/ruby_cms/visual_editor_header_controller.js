import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["pageSelector"]
  
  static values = {
    currentPage: String
  }

  changePage(event) {
    const selectedPage = event.target.value
    window.location.href = `/admin/visual_editor?page=${selectedPage}`
  }

  refresh() {
    const iframe = document.querySelector('[data-ruby-cms--visual-editor-target="previewFrame"]')
    if (iframe) {
      iframe.src = iframe.src
    }
  }
}
