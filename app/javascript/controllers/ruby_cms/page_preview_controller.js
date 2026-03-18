import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static values = {
    page: String,
    editMode: Boolean,
  };

  connect() {
    if (this.editModeValue) {
      this.enableEditMode();
    }

    this.boundHandleMessage = this.handleMessage.bind(this);
    window.addEventListener("message", this.boundHandleMessage);
  }

  disconnect() {
    window.removeEventListener("message", this.boundHandleMessage);
    this.disableEditMode();
  }

  enableEditMode() {
    this.boundHandleBlockClick = this.handleBlockClick.bind(this);
    this.element.addEventListener("click", this.boundHandleBlockClick);
  }

  disableEditMode() {
    if (this.boundHandleBlockClick) {
      this.element.removeEventListener("click", this.boundHandleBlockClick);
    }
  }

  handleBlockClick(event) {
    const blockElement =
      event.target.closest(".ruby_cms-content-block") ||
      event.target.closest(".content-block");
    if (!blockElement) return;

    event.preventDefault();
    event.stopPropagation();

    const blockId =
      blockElement.dataset.blockId || blockElement.dataset.contentKey;
    if (!blockId) {
      console.warn(
        "Content block found but no blockId or contentKey data attribute",
      );
      return;
    }

    const allWithSameId = this.element.querySelectorAll(
      `[data-block-id="${blockId}"], [data-content-key="${blockId}"]`,
    );
    const blockIndex = Array.from(allWithSameId).indexOf(blockElement);

    if (window.parent && window.parent !== window) {
      window.parent.postMessage(
        {
          type: "CONTENT_BLOCK_CLICKED",
          blockId,
          blockIndex,
          page: this.getCurrentPage(),
        },
        window.location.origin,
      );
    }
  }

  handleMessage(event) {
    if (event.origin !== window.location.origin) return;
    const { type, blockId, blockIndex = 0 } = event.data;

    if (type === "HIGHLIGHT_BLOCK") {
      this.highlightBlock(blockId, blockIndex);
    } else if (type === "CLEAR_HIGHLIGHT") {
      this.clearHighlight();
    } else if (type === "content-updated") {
      this.handleContentUpdate(event.data);
    } else if (type === "UPDATE_BLOCK_CONTENT") {
      this.updateBlockContent(event.data);
    }
  }

  highlightBlock(blockId, blockIndex = 0) {
    this.clearHighlight();

    const selector = `[data-block-id="${blockId}"], [data-content-key="${blockId}"]`;
    const matching = this.element.querySelectorAll(selector);
    const target = matching[blockIndex] || matching[0];
    if (target) {
      target.classList.add("editing");
      target.scrollIntoView({ behavior: "smooth", block: "center" });
    }
  }

  clearHighlight() {
    this.element
      .querySelectorAll(".content-block.editing, .ruby_cms-content-block.editing")
      .forEach((el) => el.classList.remove("editing"));
  }

  handleContentUpdate(data) {
    const blockIndex = data.blockIndex ?? 0;
    const key = data.key;
    const elements = this.element.querySelectorAll(
      `[data-content-key="${key}"], [data-block-id="${key}"]`,
    );
    const element = elements[blockIndex] || elements[0];
    if (element) {
      const contentEl =
        element.querySelector("[data-content-target]") || element;
      contentEl.innerHTML = data.content ?? "";
    }
  }

  updateBlockContent({ blockId, content, contentType }) {
    const blockElement = this.element.querySelector(
      `[data-block-id="${blockId}"], [data-content-key="${blockId}"]`,
    );
    if (blockElement) {
      if (contentType === "rich_text") {
        blockElement.innerHTML = content;
      } else {
        blockElement.textContent = content;
      }
    }
  }

  getCurrentPage() {
    if (this.hasPageValue) return this.pageValue;
    const urlParams = new URLSearchParams(window.location.search);
    return urlParams.get("page") || "home";
  }
}
