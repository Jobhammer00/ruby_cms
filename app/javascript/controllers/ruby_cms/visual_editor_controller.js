import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "modal",
    "modalBody",
    "previewFrame",
    "contentType",
    "contentInput",
    "richContentInput",
    "richTextContainer",
    "textContainer",
    "blockKey",
    "charCount",
    "lastUpdated",
    "saveButton",
    "toast",
    "toastMessage"
  ]
  
  static values = {
    currentPage: String
  }

  connect() {
    this.currentContentBlockKey = null
    this.currentContentBlockLocale = null
    this.editMode = false
    
    // Listen for messages from iframe
    window.addEventListener("message", this.handleMessage.bind(this))
    
    // Listen for Escape key globally when modal is open
    this.boundHandleEscape = this.handleEscape.bind(this)
    
    // Listen for iframe load
    this.previewFrameTarget.addEventListener("load", () => {
      console.log("Preview frame loaded")
    })
  }

  disconnect() {
    window.removeEventListener("message", this.handleMessage.bind(this))
    document.removeEventListener("keydown", this.boundHandleEscape)
  }

  handleMessage(event) {
    // In production, validate event.origin
    // if (event.origin !== window.location.origin) return
    
    const { type, blockId, blockIndex, page } = event.data
    
    if (type === "CONTENT_BLOCK_CLICKED") {
      this.openBlockEditor(blockId, blockIndex)
    }
  }

  async openBlockEditor(blockKey, blockIndex = 0) {
    this.currentContentBlockKey = blockKey
    this.blockKeyTarget.textContent = blockKey
    
    try {
      // Fetch content block data
      const response = await fetch(`/admin/content_blocks?search=${encodeURIComponent(blockKey)}&format=json`, {
        headers: {
          "Accept": "application/json"
        }
      })
      
      if (!response.ok) {
        throw new Error("Failed to fetch content block")
      }
      
      const data = await response.json()
      const blocks = data.content_blocks || []
      // Find block by key, prefer current locale if available
      const currentLocale = this.getCurrentLocale()
      const block = blocks.find(b => b.key === blockKey && b.locale === currentLocale) ||
                    blocks.find(b => b.key === blockKey) ||
                    blocks[blockIndex] ||
                    {}
      
      // Store locale for saving
      this.currentContentBlockLocale = block.locale || currentLocale
      
      // Populate form
      this.contentTypeTarget.value = block.content_type || "text"
      this.changeContentType()
      
      if (block.content_type === "rich_text") {
        const editor = this.richTextContainerTarget.querySelector("trix-editor")
        if (editor) {
          editor.editor.loadHTML(block.rich_content || "")
        }
      } else {
        this.contentInputTarget.value = block.content || ""
      }
      
      this.lastUpdatedTarget.textContent = block.updated_at || "Never"
      this.updateCharCount()
      
      // Show modal
      this.modalTarget.classList.add("ruby_cms-visual-editor-modal--visible")
      
      // Add Escape key listener when modal opens
      document.addEventListener("keydown", this.boundHandleEscape)
      
      // Focus the first input for better UX
      setTimeout(() => {
        if (this.contentTypeTarget.value === "rich_text") {
          const editor = this.richTextContainerTarget.querySelector("trix-editor")
          editor?.focus()
        } else {
          this.contentInputTarget.focus()
        }
      }, 100)
      
      // Highlight block in preview
      this.sendMessageToPreview({
        type: "HIGHLIGHT_BLOCK",
        blockId: blockKey,
        blockIndex: blockIndex
      })
      
    } catch (error) {
      console.error("Error loading content block:", error)
      alert("Failed to load content block")
    }
  }

  closeModal() {
    this.modalTarget.classList.remove("ruby_cms-visual-editor-modal--visible")
    this.currentContentBlockKey = null
    this.currentContentBlockLocale = null
    
    // Remove Escape key listener when modal closes
    document.removeEventListener("keydown", this.boundHandleEscape)
    
    // Clear highlight in preview
    this.sendMessageToPreview({ type: "CLEAR_HIGHLIGHT" })
  }
  
  handleEscape(event) {
    // Only handle Escape if modal is visible
    if (event.key === "Escape" && this.modalTarget.classList.contains("ruby_cms-visual-editor-modal--visible")) {
      event.preventDefault()
      event.stopPropagation()
      this.closeModal()
    }
  }

  changeContentType() {
    const contentType = this.contentTypeTarget.value
    
    if (contentType === "rich_text") {
      this.textContainerTarget.style.display = "none"
      this.richTextContainerTarget.classList.add("ruby_cms-visual-editor-modal__rich-text-container--visible")
    } else {
      this.textContainerTarget.style.display = "block"
      this.richTextContainerTarget.classList.remove("ruby_cms-visual-editor-modal__rich-text-container--visible")
    }
    
    this.updateCharCount()
  }

  updateCharCount() {
    const contentType = this.contentTypeTarget.value
    let content = ""
    
    if (contentType === "rich_text") {
      const editor = this.richTextContainerTarget.querySelector("trix-editor")
      if (editor && editor.editor) {
        content = editor.editor.getDocument().toString()
      }
    } else {
      content = this.contentInputTarget.value
    }
    
    this.charCountTarget.textContent = `${content.length} characters`
  }

  async saveContent(event) {
    event.preventDefault()
    
    if (!this.currentContentBlockKey) return
    
    const contentType = this.contentTypeTarget.value
    const payload = {
      key: this.currentContentBlockKey,
      content_type: contentType,
      locale: this.currentContentBlockLocale || null
    }
    
    if (contentType === "rich_text") {
      const editor = this.richTextContainerTarget.querySelector("trix-editor")
      payload.rich_content = editor ? editor.value : ""
    } else {
      payload.content = this.contentInputTarget.value
    }
    
    try {
      this.saveButtonTarget.disabled = true
      this.saveButtonTarget.textContent = "Saving..."
      
      const response = await fetch("/admin/visual_editor/quick_update", {
        method: "PATCH",
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
          "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content
        },
        body: JSON.stringify(payload)
      })
      
      const data = await response.json()
      
      if (!response.ok || !data.success) {
        throw new Error(data.message || "Failed to save")
      }
      
      // Update last updated time
      this.lastUpdatedTarget.textContent = data.updated_at
      
      // Update content in preview without refreshing
      const contentToDisplay = contentType === "rich_text" 
        ? (data.rich_content_html || data.content || "")
        : (data.content || "")
      
      this.sendMessageToPreview({
        type: "UPDATE_BLOCK_CONTENT",
        blockId: this.currentContentBlockKey,
        content: contentToDisplay,
        contentType: contentType
      })
      
      // Close modal
      this.closeModal()
      
      // Show success toast
      this.showToast(data.message || "Content updated successfully")
      
    } catch (error) {
      console.error("Error saving content:", error)
      alert(error.message || "Failed to save content")
    } finally {
      this.saveButtonTarget.disabled = false
      this.saveButtonTarget.textContent = "Save Changes"
    }
  }

  handleKeydown(event) {
    // Enter to submit (but Shift+Enter allows newline in textareas)
    if (event.key === "Enter") {
      const isTextarea = event.target.matches("textarea")
      const isTrixEditor = event.target.matches("trix-editor") || event.target.closest("trix-editor")
      
      // Allow Shift+Enter for newlines in textareas/trix
      if ((isTextarea || isTrixEditor) && event.shiftKey) {
        return // Let the default behavior happen (newline)
      }
      
      // Enter without Shift submits the form
      if (!isTextarea && !isTrixEditor) {
        // Enter outside textarea/trix submits
        event.preventDefault()
        this.saveContent(event)
      } else if (!event.shiftKey) {
        // Enter in textarea/trix without Shift submits
        event.preventDefault()
        this.saveContent(event)
      }
    }
    
    // Ctrl/Cmd + Enter to save (alternative shortcut)
    if ((event.ctrlKey || event.metaKey) && event.key === "Enter") {
      event.preventDefault()
      this.saveContent(event)
    }
  }

  refreshPreview() {
    const iframe = this.previewFrameTarget
    iframe.src = iframe.src
  }

  sendMessageToPreview(message) {
    const iframe = this.previewFrameTarget
    if (iframe && iframe.contentWindow) {
      iframe.contentWindow.postMessage(message, "*")
    }
  }

  showToast(message) {
    this.toastMessageTarget.textContent = message
    this.toastTarget.classList.add("ruby_cms-visual-editor-toast--visible")
    
    setTimeout(() => {
      this.toastTarget.classList.remove("ruby_cms-visual-editor-toast--visible")
    }, 3000)
  }

  getCurrentLocale() {
    // Try to get locale from meta tag
    const metaLocale = document.querySelector('meta[name="locale"]')
    if (metaLocale) {
      return metaLocale.content
    }
    // Try HTML lang attribute
    const htmlLang = document.documentElement.lang
    if (htmlLang) {
      return htmlLang
    }
    // Fallback to default
    return 'en'
  }
}
