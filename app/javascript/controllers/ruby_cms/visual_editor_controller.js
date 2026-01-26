import { Controller } from "@hotwired/stimulus"

// Helper to only log errors in development
function logError(...args) {
  const env = document.querySelector('meta[name="rails-env"]')?.content;
  if (env === "development") {
    console.error(...args);
  }
}

// Connects to data-controller="ruby-cms--visual-editor"
export default class extends Controller {
  static targets = [
    "previewFrame",
    "editModal",
    "editForm",
    "blockId",
    "blockKey",
    "editModalKey",
    "blockTitle",
    "blockContent",
    "blockRichContent",
    "blockContentType",
    "blockPublished",
    "modalClose",
    "bulkSelectAll",
    "bulkId",
    "bulkSelectionCount",
    "bulkActionType",
    "bulkForm"
  ]
  
  static values = { 
    nonce: String,
    allowedOrigin: String,
    contentBlocksBase: String,
    csrfToken: String,
    previewPath: String
  }

  connect() {
    this.setupMessageListener()
    this.setupModalHandlers()
    this.setupBulkHandlers()
    this.setupKeyboardShortcuts()
  }

  disconnect() {
    window.removeEventListener('message', this.boundHandleMessage)
    document.removeEventListener('keydown', this.boundHandleKeydown)
  }

  setupMessageListener() {
    this.boundHandleMessage = this.handleMessage.bind(this)
    window.addEventListener('message', this.boundHandleMessage)
  }

  setupModalHandlers() {
    if (this.hasModalCloseTarget) {
      this.modalCloseTarget.addEventListener('click', () => this.hideModal())
    }
    if (this.hasEditModalTarget) {
      this.editModalTarget.addEventListener('click', (e) => {
        if (e.target === this.editModalTarget) {
          this.hideModal()
        }
      })
    }
  }

  setupBulkHandlers() {
    if (this.hasBulkSelectAllTarget) {
      this.bulkSelectAllTarget.addEventListener('change', (e) => {
        this.bulkIdTargets.forEach(checkbox => {
          checkbox.checked = e.target.checked
        })
        this.updateBulkCount()
      })
    }
    this.bulkIdTargets.forEach(checkbox => {
      checkbox.addEventListener('change', () => this.updateBulkCount())
    })
  }

  setupKeyboardShortcuts() {
    this.boundHandleKeydown = this.handleKeydown.bind(this)
    document.addEventListener('keydown', this.boundHandleKeydown)
  }

  handleKeydown(event) {
    // Only handle shortcuts when modal is open
    if (!this.hasEditModalTarget || this.editModalTarget.classList.contains('hidden')) {
      return
    }

    // Esc to close modal
    if (event.key === 'Escape') {
      event.preventDefault()
      this.hideModal()
      return
    }

    // Cmd+S or Ctrl+S to save
    if ((event.metaKey || event.ctrlKey) && event.key === 's') {
      event.preventDefault()
      if (this.hasEditFormTarget) {
        this.saveContentBlock(new Event('submit'))
      }
      return
    }
  }

  handleMessage(event) {
    if (event.origin !== this.allowedOriginValue) return
    
    const data = event.data
    if (!data || data.type !== "ruby_cms:content_block:click" || data.nonce !== this.nonceValue) return
    
    if (!this.hasPreviewFrameTarget || !this.previewFrameTarget.contentWindow || event.source !== this.previewFrameTarget.contentWindow) return
    
    const blockId = data.blockId
    if (!blockId) return
    
    this.fetchContentBlock(blockId)
  }

  async fetchContentBlock(id) {
    try {
      const response = await fetch(`${this.contentBlocksBaseValue}/${id}.json`, {
        headers: { "Accept": "application/json" }
      })
      
      if (!response.ok) throw new Error(`HTTP ${response.status}`)
      
      const block = await response.json()
      this.populateModal(block)
      this.showModal()
    } catch (error) {
      logError('Failed to fetch content block:', error)
    }
  }

  populateModal(block) {
    if (this.hasBlockIdTarget) this.blockIdTarget.value = block.id
    if (this.hasBlockKeyTarget) this.blockKeyTarget.value = block.key || ""
    if (this.hasEditModalKeyTarget) this.editModalKeyTarget.textContent = block.key || ""
    if (this.hasBlockTitleTarget) this.blockTitleTarget.value = block.title || ""
    if (this.hasBlockContentTarget) this.blockContentTarget.value = block.content || ""
    if (this.hasBlockRichContentTarget) this.blockRichContentTarget.value = block.rich_content_html || ""
    if (this.hasBlockContentTypeTarget) this.blockContentTypeTarget.value = block.content_type || "text"
    if (this.hasBlockPublishedTarget) this.blockPublishedTarget.checked = !!block.published
  }

  showModal() {
    if (this.hasEditModalTarget) {
      this.editModalTarget.classList.remove("hidden")
      this.editModalTarget.style.display = "flex"
      // Focus first input for better UX
      if (this.hasBlockTitleTarget) {
        setTimeout(() => this.blockTitleTarget.focus(), 100)
      }
    }
  }

  hideModal() {
    if (this.hasEditModalTarget) {
      this.editModalTarget.classList.add("hidden")
      this.editModalTarget.style.display = "none"
    }
  }

  async saveContentBlock(event) {
    event.preventDefault()
    
    if (!this.hasBlockIdTarget || !this.blockIdTarget.value) return
    
    const payload = {
      content_block: {
        title: this.hasBlockTitleTarget ? this.blockTitleTarget.value : "",
        content: this.hasBlockContentTarget ? this.blockContentTarget.value : "",
        content_type: this.hasBlockContentTypeTarget ? this.blockContentTypeTarget.value : "text",
        published: this.hasBlockPublishedTarget ? this.blockPublishedTarget.checked : false
      }
    }
    
    if (this.hasBlockRichContentTarget) {
      payload.content_block.rich_content = this.blockRichContentTarget.value
    }
    
    try {
      const response = await fetch(`${this.contentBlocksBaseValue}/${this.blockIdTarget.value}`, {
        method: "PATCH",
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
          "X-CSRF-Token": this.csrfTokenValue
        },
        body: JSON.stringify(payload)
      })
      
      if (response.ok) {
        this.showToast('Content block saved successfully', 'success')
        this.hideModal()
        this.reloadPreview()
      } else {
        const errorData = await response.json().catch(() => ({}))
        this.showToast(errorData.error || 'Failed to save content block', 'error')
      }
    } catch (error) {
      logError('Failed to save content block:', error)
      this.showToast('Failed to save content block', 'error')
    }
  }

  reloadPreview() {
    if (this.hasPreviewFrameTarget && this.previewFrameTarget.contentWindow) {
      this.previewFrameTarget.contentWindow.postMessage({
        type: "ruby_cms:preview:reload",
        nonce: this.nonceValue
      }, this.allowedOriginValue)
    }
  }

  handlePageKeyChange(event) {
    if (!this.hasPreviewFrameTarget) return
    
    const pageKey = event.target.value
    const newUrl = `${this.previewPathValue}?page_key=${encodeURIComponent(pageKey)}&nonce=${encodeURIComponent(this.nonceValue)}`
    this.previewFrameTarget.src = newUrl
  }

  handleBulkUnpublish(event) {
    event.preventDefault()
    if (this.hasBulkActionTypeTarget) {
      this.bulkActionTypeTarget.value = "unpublish"
    }
    if (this.hasBulkFormTarget) {
      this.bulkFormTarget.requestSubmit()
    }
  }

  updateBulkCount() {
    const count = this.bulkIdTargets.filter(cb => cb.checked).length
    if (this.hasBulkSelectionCountTarget) {
      this.bulkSelectionCountTarget.textContent = count ? `${count} selected` : ""
    }
  }

  showToast(message, type = 'success') {
    const toast = document.createElement('div')
    toast.className = `ruby_cms-toast ruby_cms-toast-${type}`
    toast.textContent = message
    toast.setAttribute('role', 'alert')
    
    // Add to body
    document.body.appendChild(toast)
    
    // Animate in
    setTimeout(() => toast.classList.add('show'), 10)
    
    // Remove after 3 seconds
    setTimeout(() => {
      toast.classList.remove('show')
      setTimeout(() => toast.remove(), 300)
    }, 3000)
  }
}
