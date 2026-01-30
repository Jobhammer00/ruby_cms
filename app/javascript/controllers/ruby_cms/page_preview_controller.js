import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static values = {
    editMode: Boolean,
  };

  connect() {
    if (this.editModeValue) {
      this.enableEditMode();
    }

    // Listen for messages from parent window
    window.addEventListener("message", this.handleMessage.bind(this));
  }

  disconnect() {
    window.removeEventListener("message", this.handleMessage.bind(this));
    this.disableEditMode();
  }

  enableEditMode() {
    // Delegate clicks to content blocks
    this.element.addEventListener("click", this.handleBlockClick.bind(this));
  }

  disableEditMode() {
    this.element.removeEventListener("click", this.handleBlockClick.bind(this));
  }

  handleBlockClick(event) {
    // Find the closest content block element
    const blockElement = event.target.closest(".ruby_cms-content-block");

    if (!blockElement) return;

    // Prevent default link behavior if clicked element is inside a content block
    event.preventDefault();
    event.stopPropagation();

    // Get block information
    const blockId =
      blockElement.dataset.blockId || blockElement.dataset.contentKey;
    const blockIndex = 0;

    if (!blockId) {
      console.warn(
        "Content block found but no blockId or contentKey data attribute",
      );
      return;
    }

    // Send message to parent window
    window.parent.postMessage(
      {
        type: "CONTENT_BLOCK_CLICKED",
        blockId: blockId,
        blockIndex: blockIndex,
        page: this.getCurrentPage(),
      },
      "*",
    );
  }

  handleMessage(event) {
    // Listen for messages from parent (visual editor)
    const { type, blockId } = event.data;

    if (type === "HIGHLIGHT_BLOCK") {
      this.highlightBlock(blockId);
    } else if (type === "CLEAR_HIGHLIGHT") {
      this.clearHighlight();
    } else if (type === "UPDATE_BLOCK_CONTENT") {
      this.updateBlockContent(event.data);
    }
  }

  highlightBlock(blockId) {
    // Clear any existing highlights
    this.clearHighlight();

    // Find and highlight the block
    const blockElement = this.element.querySelector(
      `.ruby_cms-content-block[data-block-id="${blockId}"], ` +
        `.ruby_cms-content-block[data-content-key="${blockId}"]`,
    );

    if (blockElement) {
      blockElement.classList.add("editing");
      blockElement.scrollIntoView({ behavior: "smooth", block: "center" });
    }
  }

  clearHighlight() {
    const highlightedBlocks = this.element.querySelectorAll(
      ".ruby_cms-content-block.editing",
    );
    highlightedBlocks.forEach((block) => {
      block.classList.remove("editing");
    });
  }

  updateBlockContent({ blockId, content, contentType }) {
    const blockElement = this.element.querySelector(
      `.ruby_cms-content-block[data-block-id="${blockId}"], ` +
        `.ruby_cms-content-block[data-content-key="${blockId}"]`,
    );

    if (blockElement) {
      // Update the content
      if (contentType === "rich_text") {
        blockElement.innerHTML = content;
      } else {
        blockElement.textContent = content;
      }
    }
  }

  getCurrentPage() {
    // Try to get current page from URL params or return default
    const urlParams = new URLSearchParams(window.location.search);
    return urlParams.get("page") || "home";
  }
}
