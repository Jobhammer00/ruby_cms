import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static values = {
    editMode: Boolean,
    allowedOrigin: String,
    nonce: String,
  };

  connect() {
    this.boundHandleMessage = this.handleMessage.bind(this);
    window.addEventListener("message", this.boundHandleMessage);

    // Wait for DOM to be ready before enabling edit mode
    if (this.editModeValue) {
      if (document.readyState === "loading") {
        document.addEventListener("DOMContentLoaded", () => {
          // Small delay to ensure all content blocks are rendered
          setTimeout(() => this.enableEditMode(), 100);
        });
      } else {
        // DOM already loaded
        setTimeout(() => this.enableEditMode(), 100);
      }
    }
  }

  disconnect() {
    window.removeEventListener("message", this.boundHandleMessage);
  }

  handleMessage(event) {
    // Origin validation (uncomment and set allowedOriginValue in production)
    // if (event.origin !== this.allowedOriginValue) return

    // Basic preview reload support (e.g. from Turbo/previewer)
    if (
      event.data &&
      event.data.type === "ruby_cms:preview:reload" &&
      this.nonceValue &&
      event.data.nonce === this.nonceValue
    ) {
      location.reload();
      return;
    }

    // Frame communication features (edit/highlight/content events)
    const { type, blockId, blockIndex, key, content, contentType } = event.data || {};

    switch (type) {
      case "HIGHLIGHT_BLOCK":
        this.highlightBlock(blockId, blockIndex);
        break;
      case "CLEAR_HIGHLIGHT":
        this.clearHighlight();
        break;
      case "content-updated":
        this.updateBlockContent(key, content, blockIndex);
        break;
      case "UPDATE_BLOCK_CONTENT":
        this.updateBlockContent(blockId, content, blockIndex, contentType);
        break;
      case "SHOW_EDIT_MODE":
        this.enableEditMode();
        break;
      case "HIDE_EDIT_MODE":
        this.disableEditMode();
        break;
      default:
        // Do nothing for unknown events
        break;
    }
  }

  enableEditMode() {
    const blocks = document.querySelectorAll(".ruby_cms-content-block");
    blocks.forEach((block, index) => {
      block.style.cursor = "pointer";
      // Remove any previous click listeners
      block.replaceWith(block.cloneNode(true));
      const freshBlock = document.querySelectorAll(".ruby_cms-content-block")[
        index
      ];
      freshBlock.style.cursor = "pointer";
      freshBlock.addEventListener("click", (e) => {
        e.preventDefault();
        this.handleBlockClick(freshBlock, index);
      });
    });
  }

  disableEditMode() {
    const blocks = document.querySelectorAll(".ruby_cms-content-block");
    blocks.forEach((block) => {
      block.style.cursor = "default";
      block.replaceWith(block.cloneNode(true)); // Remove any event listeners
    });
  }

  handleBlockClick(block, index) {
    const blockId = block.dataset.blockId;
    if (!blockId) return;

    window.parent.postMessage(
      {
        type: "CONTENT_BLOCK_CLICKED",
        blockId: blockId,
        blockIndex: index,
        page: this.getCurrentPage(),
      },
      "*",
    );
  }

  highlightBlock(blockId, blockIndex = 0) {
    this.clearHighlight();
    const blocks = document.querySelectorAll(`[data-block-id="${blockId}"]`);
    if (blocks.length > 0) {
      const block = blocks[blockIndex] || blocks[0];
      block.classList.add("editing");
      block.scrollIntoView({ behavior: "smooth", block: "center" });
    }
  }

  clearHighlight() {
    const highlighted = document.querySelectorAll(".editing");
    highlighted.forEach((el) => el.classList.remove("editing"));
  }

  updateBlockContent(key, content, blockIndex = 0, contentType = null) {
    const blocks = document.querySelectorAll(`[data-block-id="${key}"]`);
    if (blocks.length > 0) {
      const block = blocks[blockIndex] || blocks[0];
      
      // Update content based on type
      if (contentType === "rich_text" && content) {
        // For rich text, update innerHTML
        block.innerHTML = content;
      } else {
        // For plain text, find content element or update block directly
        const contentElement = block.querySelector("[data-content]") || block;
        if (contentElement) {
          contentElement.textContent = content;
        } else {
          block.textContent = content;
        }
      }
      
      // Visual feedback
      block.style.transition = "background-color 0.3s ease";
      block.style.backgroundColor = "rgba(34, 197, 94, 0.1)";
      setTimeout(() => {
        block.style.backgroundColor = "";
      }, 500);
    }
  }

  getCurrentPage() {
    const params = new URLSearchParams(window.location.search);
    return params.get("page") || "home";
  }
}
