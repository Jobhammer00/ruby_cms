import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="ruby-cms--page-preview"
export default class extends Controller {
  static values = {
    nonce: String,
    allowedOrigin: String
  }

  connect() {
    this.setupContentBlockHandlers()
    this.setupMessageListener()
  }

  disconnect() {
    window.removeEventListener('message', this.boundHandleMessage)
  }

  setupContentBlockHandlers() {
    document.querySelectorAll('.content-block').forEach(el => {
      el.style.cursor = "pointer"
      
      el.addEventListener('mouseenter', () => {
        el.style.outline = "2px dashed #3b82f6"
        el.style.outlineOffset = "2px"
      })
      
      el.addEventListener('mouseleave', () => {
        el.style.outline = ""
        el.style.outlineOffset = ""
      })
      
      el.addEventListener('click', (e) => {
        e.preventDefault()
        const blockId = el.getAttribute('data-block-id')
        const key = el.getAttribute('data-content-key')
        
        if (blockId && key && window.parent !== window) {
          window.parent.postMessage({
            type: "ruby_cms:content_block:click",
            nonce: this.nonceValue,
            blockId: blockId,
            key: key
          }, this.allowedOriginValue)
        }
      })
    })
  }

  setupMessageListener() {
    this.boundHandleMessage = this.handleMessage.bind(this)
    window.addEventListener('message', this.boundHandleMessage)
  }

  handleMessage(event) {
    if (event.source !== window.parent) return
    if (event.origin !== this.allowedOriginValue) return
    
    if (event.data && event.data.type === "ruby_cms:preview:reload" && event.data.nonce === this.nonceValue) {
      location.reload()
    }
  }
}
