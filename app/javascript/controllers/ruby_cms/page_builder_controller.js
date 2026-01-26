import { Controller } from "@hotwired/stimulus";

// Helper to only log errors in development
function logError(...args) {
  const env = document.querySelector('meta[name="rails-env"]')?.content;
  if (env === "development") {
    console.error(...args);
  }
}

// Connects to data-controller="ruby-cms--page-builder"
export default class extends Controller {
  static targets = [
    "canvas",
    "region",
    "regionNodes",
    "node",
    "propsEditor",
    "propsForm",
    "pageSelect",
    "componentSearch",
    "componentPalette",
  ];

  static values = {
    pageId: Number,
    csrfToken: String,
    basePath: String,
    apiBasePath: String,
  };

  connect() {
    this.selectedNode = null;
    this.draggedComponent = null;
    this.draggedNodeId = null;
    this.currentPageId = this.pageIdValue || null;
    this.isDragging = false;
  }

  apiBase() {
    return this.hasApiBasePathValue && this.apiBasePathValue
      ? this.apiBasePathValue
      : this.basePathValue;
  }

  async parseJsonResponse(response) {
    const contentType = response.headers.get("content-type") || "";
    if (contentType.includes("application/json")) {
      return await response.json();
    }

    const body = await response.text();
    throw new Error(
      `Expected JSON, got ${contentType || "unknown"} (HTTP ${response.status}): ${body.slice(0, 200)}`,
    );
  }

  handlePageChange(event) {
    const pageId = event.target.value;
    if (pageId) {
      window.location.href = `${this.basePathValue}?page_id=${pageId}`;
    }
  }

  getPageId() {
    // Get page_id from select, data attribute, or value
    if (this.hasPageSelectTarget) {
      return this.pageSelectTarget.value;
    }
    return this.currentPageId || this.pageIdValue;
  }

  disconnect() {
    // Cleanup if needed
  }

  handleDragStart(event) {
    this.isDragging = true;
    this.draggedComponent = {
      key: event.currentTarget.dataset.componentKey,
      name: event.currentTarget.dataset.componentName,
    };
    event.dataTransfer.effectAllowed = "move";
    event.currentTarget.classList.add("ruby_cms-dragging");
  }

  handleDragEnd(event) {
    this.isDragging = false;
    event.currentTarget.classList.remove("ruby_cms-dragging");
    // Remove all drag-over classes
    this.regionTargets?.forEach((region) => {
      region.classList.remove("ruby_cms-drag-over");
    });
  }

  handleDragOver(event) {
    event.preventDefault();
    event.dataTransfer.dropEffect = "move";
  }

  handleDragEnter(event) {
    if (event.currentTarget.dataset.regionKey) {
      event.currentTarget.classList.add("ruby_cms-drag-over");
    }
  }

  handleDragLeave(event) {
    // Only remove class if we're actually leaving the element (not entering a child)
    if (event.currentTarget === event.target) {
      event.currentTarget.classList.remove("ruby_cms-drag-over");
    }
  }

  filterComponents(event) {
    const searchTerm = event.target.value.toLowerCase().trim();
    const items =
      this.componentPaletteTarget?.querySelectorAll(".component-item");
    const categories = this.componentPaletteTarget?.querySelectorAll(
      ".component-category",
    );

    if (!items || !categories) return;

    items.forEach((item) => {
      const name = item.dataset.componentName?.toLowerCase() || "";
      const key = item.dataset.componentKey?.toLowerCase() || "";
      const matches =
        !searchTerm || name.includes(searchTerm) || key.includes(searchTerm);
      item.classList.toggle("hidden", !matches);
    });

    // Hide categories with no visible items
    categories.forEach((category) => {
      const visibleItems = category.querySelectorAll(
        ".component-item:not(.hidden)",
      );
      category.classList.toggle("hidden", visibleItems.length === 0);
    });
  }

  async handleDrop(event) {
    event.preventDefault();
    event.stopPropagation();

    const targetNode = event.currentTarget.closest("[data-node-id]");
    const region = event.currentTarget.closest("[data-region-key]");

    if (!region) {
      this.isDragging = false;
      return;
    }

    const regionKey = region.dataset.regionKey;
    let parentId = null;

    // If dropped on a node, nest under it
    if (targetNode) {
      parentId = targetNode.dataset.nodeId;
      targetNode.classList.remove(
        "border-blue-400",
        "bg-blue-50",
        "ruby_cms-drag-over",
      );
    }

    if (this.draggedComponent) {
      // Creating new component
      await this.createNode(regionKey, this.draggedComponent.key, parentId);
      this.draggedComponent = null;
    } else if (this.draggedNodeId) {
      // Moving existing node
      await this.moveNode(this.draggedNodeId, regionKey, parentId);
      this.draggedNodeId = null;
    }

    // Clean up drag state
    region.classList.remove("border-blue-500", "ruby_cms-drag-over");
    this.nodeTargets.forEach((node) =>
      node.classList.remove("ruby_cms-dragging"),
    );
    this.isDragging = false;
  }

  handleNodeDragStart(event) {
    this.isDragging = true;
    event.dataTransfer.effectAllowed = "move";
    this.draggedNodeId = event.currentTarget.dataset.nodeId;
    event.currentTarget.classList.add("ruby_cms-dragging");
    // Store original parent/region for potential rollback
    const nodeEl = event.currentTarget;
    this.draggedNodeOriginalParent =
      nodeEl.closest("[data-node-id]")?.dataset.nodeId || null;
    this.draggedNodeOriginalRegion =
      nodeEl.closest("[data-region-key]")?.dataset.regionKey;
  }

  async createNode(regionKey, componentKey, parentId = null) {
    const pageId = this.getPageId();
    if (!pageId) {
      alert("No page selected");
      return;
    }

    try {
      const response = await fetch(
        `${this.apiBase()}/nodes?page_id=${pageId}`,
        {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            Accept: "application/json",
            "X-CSRF-Token": this.csrfTokenValue,
          },
          body: JSON.stringify({
            node: {
              component_key: componentKey,
              parent_id: parentId,
              props: {},
            },
            region_key: regionKey,
          }),
        },
      );

      const data = await this.parseJsonResponse(response);
      if (data.success) {
        this.addNodeToRegion(regionKey, data.node, parentId);
      } else {
        logError("Failed to create node:", data.errors);
        alert(
          "Failed to create component: " +
            (data.errors || "Unknown error").join(", "),
        );
      }
    } catch (error) {
      logError("Error creating node:", error);
      alert("Error creating component. Please try again.");
    }
  }

  addNodeToRegion(regionKey, nodeData, parentId = null) {
    const region = this.regionTargets.find(
      (r) => r.dataset.regionKey === regionKey,
    );
    if (!region) return;

    let targetContainer;
    if (parentId) {
      // Find parent node and its children container
      const parentNode = region.querySelector(`[data-node-id="${parentId}"]`);
      if (!parentNode) {
        // Fallback to root container
        targetContainer = region.querySelector(
          "[data-ruby-cms--page-builder-target='regionNodes']",
        );
      } else {
        // Find or create children container in parent
        let childrenContainer = parentNode.querySelector(
          "[data-ruby-cms--page-builder-target='nodeChildren']",
        );
        if (!childrenContainer) {
          childrenContainer = document.createElement("div");
          childrenContainer.className =
            "ml-4 mt-2 space-y-2 border-l-2 border-gray-200 pl-3";
          childrenContainer.dataset.rubyCmsPageBuilderTarget = "nodeChildren";
          parentNode.appendChild(childrenContainer);
        }
        targetContainer = childrenContainer;
      }
    } else {
      targetContainer = region.querySelector(
        "[data-ruby-cms--page-builder-target='regionNodes']",
      );
    }

    if (!targetContainer) return;

    const nodeElement = this.createNodeElement(nodeData);
    targetContainer.appendChild(nodeElement);
  }

  createNodeElement(nodeData) {
    const template = document.getElementById("node-template");
    let nodeDiv;

    // Get display text from props for preview
    const props = nodeData.props || {};
    const displayText =
      props.text || props.title || props.heading || props.content || "";
    const componentName = this.humanize(
      nodeData.component_key.split(".").pop(),
    );

    if (!template) {
      // Fallback: create element manually
      nodeDiv = document.createElement("div");
      nodeDiv.className = "ruby_cms-node";
      nodeDiv.setAttribute("draggable", "true");
      nodeDiv.dataset.nodeId = nodeData.id;
      nodeDiv.dataset.componentKey = nodeData.component_key;
      nodeDiv.dataset.rubyCmsPageBuilderTarget = "node";
      nodeDiv.dataset.action =
        "click->ruby-cms--page-builder#selectNode dragstart->ruby-cms--page-builder#handleNodeDragStart dragover->ruby-cms--page-builder#handleDragOver drop->ruby-cms--page-builder#handleDrop";

      const previewText = displayText
        ? `<span class="ruby_cms-node-preview-text">${this.escapeHtml(displayText.substring(0, 30))}</span>`
        : "";

      nodeDiv.innerHTML = `
        <div class="ruby_cms-node-header">
          <div class="ruby_cms-node-title">
            <svg class="ruby_cms-node-icon" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 21a4 4 0 01-4-4V5a2 2 0 012-2h4a2 2 0 012 2v12a4 4 0 01-4 4zm0 0h12a2 2 0 002-2v-4a2 2 0 00-2-2h-2.343M11 7.343l1.657-1.657a2 2 0 012.828 0l2.829 2.829a2 2 0 010 2.828l-8.486 8.485M7 17h.01"></path>
            </svg>
            <span class="ruby_cms-node-name">${componentName}</span>
            ${previewText}
          </div>
          <div class="ruby_cms-node-actions">
            <button type="button" class="ruby_cms-node-action-btn" title="Edit properties" data-node-id="${nodeData.id}" data-action="click->ruby-cms--page-builder#editNode">
              <svg class="ruby_cms-node-action-icon" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z"></path>
              </svg>
            </button>
            <button type="button" class="ruby_cms-node-action-btn ruby_cms-node-action-btn--delete" title="Delete component" data-node-id="${nodeData.id}" data-action="click->ruby-cms--page-builder#deleteNode">
              <svg class="ruby_cms-node-action-icon" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16"></path>
              </svg>
            </button>
          </div>
        </div>
      `;
    } else {
      const clone = template.content.cloneNode(true);
      nodeDiv = clone.querySelector("div");
      nodeDiv.dataset.nodeId = nodeData.id;
      nodeDiv.dataset.componentKey = nodeData.component_key;

      // Update name and add preview text
      const nameSpan = nodeDiv.querySelector(".ruby_cms-node-name");
      if (nameSpan) {
        nameSpan.textContent = componentName;
        if (displayText) {
          const previewSpan = document.createElement("span");
          previewSpan.className = "ruby_cms-node-preview-text";
          previewSpan.textContent = displayText.substring(0, 30);
          nameSpan.parentNode.appendChild(previewSpan);
        }
      }

      // Add node-id to buttons
      const buttons = nodeDiv.querySelectorAll("button[data-action]");
      buttons.forEach((btn) => {
        btn.dataset.nodeId = nodeData.id;
      });
    }

    // Render children if any
    if (nodeData.children && nodeData.children.length > 0) {
      const childrenContainer = document.createElement("div");
      childrenContainer.className = "ruby_cms-node-children";
      childrenContainer.dataset.rubyCmsPageBuilderTarget = "nodeChildren";
      nodeData.children.forEach((child) => {
        childrenContainer.appendChild(this.createNodeElement(child));
      });
      nodeDiv.appendChild(childrenContainer);
    }

    return nodeDiv;
  }

  selectNode(event) {
    // Don't select during drag operations
    if (this.isDragging) return;

    event?.stopPropagation?.();

    const nodeElement = event?.currentTarget;
    if (!nodeElement) return;

    const nodeId = nodeElement.dataset?.nodeId;
    if (!nodeId) return;

    this.selectedNode = nodeId;

    // Highlight selected node
    this.nodeTargets.forEach((node) => {
      node.classList.remove(
        "ruby_cms-node--selected",
        "border-blue-500",
        "ring-2",
        "ring-blue-500",
      );
    });
    nodeElement.classList.add("ruby_cms-node--selected");

    // Load props editor
    this.loadPropsEditor(nodeId);
  }

  async loadPropsEditor(nodeId) {
    const node = this.nodeTargets.find((n) => n.dataset.nodeId === nodeId);
    if (!node) return;

    const componentKey = node.dataset.componentKey;

    // Show props editor
    if (this.hasPropsEditorTarget) {
      this.propsEditorTarget.classList.remove("hidden", "ruby_cms-hidden");
    }

    // Show loading state
    if (this.hasPropsFormTarget) {
      this.propsFormTarget.innerHTML = `
        <p class="text-sm text-gray-500 mb-4">Loading component schema...</p>
      `;
    }

    const pageId = this.getPageId();
    if (!pageId) return;

    // Fetch component schema and current node props
    try {
      const [schemaResponse, nodeResponse] = await Promise.all([
        fetch(
          `${this.apiBase()}/component_schema?component_key=${encodeURIComponent(componentKey)}&page_id=${pageId}`,
          {
            headers: { Accept: "application/json" },
          },
        ),
        fetch(`${this.apiBase()}/nodes/${nodeId}?page_id=${pageId}`, {
          headers: { Accept: "application/json" },
        }),
      ]);

      const schemaData = await this.parseJsonResponse(schemaResponse);
      const nodeData = nodeResponse.ok
        ? await this.parseJsonResponse(nodeResponse)
        : { node: { props: {} } };

      if (schemaData.success && schemaData.schema) {
        this.renderPropsForm(
          componentKey,
          schemaData.schema,
          schemaData.name,
          nodeData.node?.props || {},
          nodeId,
        );
      } else {
        // Fallback to JSON editor
        this.renderJsonEditor(componentKey, nodeData.node?.props || {}, nodeId);
      }
    } catch (error) {
      logError("Error loading props editor:", error);
      // Fallback to JSON editor
      this.renderJsonEditor(componentKey, {}, nodeId);
    }
  }

  renderPropsForm(componentKey, schema, componentName, currentProps, nodeId) {
    if (!this.hasPropsFormTarget) return;

    const properties = schema.properties || {};
    const required = schema.required || [];

    let formHTML = `
      <div class="mb-4">
        <h3 class="text-sm font-semibold text-gray-900">${componentName || componentKey}</h3>
        ${schema.description ? `<p class="text-xs text-gray-500 mt-1">${schema.description}</p>` : ""}
      </div>
      <form data-action="submit->ruby-cms--page-builder#saveNodeProps" class="space-y-4">
        <input type="hidden" name="node_id" value="${nodeId}">
    `;

    Object.keys(properties).forEach((key) => {
      const prop = properties[key];
      const isRequired = required.includes(key);
      const currentValue =
        currentProps[key] !== undefined
          ? currentProps[key]
          : prop.default !== undefined
            ? prop.default
            : "";
      const label = prop.title || this.humanize(key);
      const description = prop.description
        ? `<p class="mt-1 text-xs text-gray-500">${prop.description}</p>`
        : "";

      formHTML += `
        <div class="ruby_cms-field">
          <label class="block text-sm font-medium text-gray-700 mb-1">
            ${label}${isRequired ? " *" : ""}
          </label>
          ${this.generateFieldHTML(key, prop, currentValue)}
          ${description}
        </div>
      `;
    });

    formHTML += `
        <button type="submit" class="ruby_cms-btn ruby_cms-btn-primary w-full">Save Properties</button>
      </form>
    `;

    this.propsFormTarget.innerHTML = formHTML;
  }

  generateFieldHTML(key, prop, value) {
    const fieldName = `props[${key}]`;
    const fieldId = `prop_${key}`;

    // Handle content_block format specially - show input with link to Visual Editor
    if (prop.format === "content_block") {
      return `
        <div class="flex gap-2">
          <input type="text" name="${fieldName}" id="${fieldId}" value="${this.escapeHtml(value)}" 
            class="ruby_cms-input block w-full rounded-md border border-gray-300 px-3 py-2" 
            placeholder="e.g., hero.button_text">
          ${
            value
              ? `<a href="/admin/content_blocks?q=${encodeURIComponent(value)}" target="_blank" 
                  class="ruby_cms-btn ruby_cms-btn-outline px-3 py-2 text-sm whitespace-nowrap" 
                  title="Edit in Visual Editor">Edit</a>`
              : ""
          }
        </div>
        <p class="mt-1 text-xs text-blue-600">
          <a href="/admin/editor" target="_blank" class="hover:underline">→ Open Visual Editor</a> to edit content blocks
        </p>`;
    }

    // Handle enum for any type (string, integer, etc.)
    if (prop.enum) {
      let options = prop.enum
        .map(
          (v) =>
            `<option value="${v}" ${String(value) === String(v) ? "selected" : ""}>${v}</option>`,
        )
        .join("");
      return `<select name="${fieldName}" id="${fieldId}" class="ruby_cms-select block w-full rounded-md border border-gray-300 px-3 py-2">${options}</select>`;
    }

    switch (prop.type) {
      case "string":
        if (
          prop.format === "textarea" ||
          (prop.maxLength && prop.maxLength > 100)
        ) {
          // Textarea
          return `<textarea name="${fieldName}" id="${fieldId}" rows="${prop.rows || 4}" class="ruby_cms-textarea block w-full rounded-md border border-gray-300 px-3 py-2" placeholder="${prop.placeholder || ""}">${this.escapeHtml(value)}</textarea>`;
        } else {
          // Text input
          return `<input type="text" name="${fieldName}" id="${fieldId}" value="${this.escapeHtml(value)}" class="ruby_cms-input block w-full rounded-md border border-gray-300 px-3 py-2" placeholder="${prop.placeholder || ""}">`;
        }
      case "number":
      case "integer":
        return `<input type="number" name="${fieldName}" id="${fieldId}" value="${value}" class="ruby_cms-input block w-full rounded-md border border-gray-300 px-3 py-2" step="${prop.type === "integer" ? 1 : prop.step || "any"}" ${prop.minimum !== undefined ? `min="${prop.minimum}"` : ""} ${prop.maximum !== undefined ? `max="${prop.maximum}"` : ""}>`;
      case "boolean":
        return `<input type="checkbox" name="${fieldName}" id="${fieldId}" value="1" ${value ? "checked" : ""} class="h-4 w-4 rounded border-gray-300">`;
      case "array":
        const arrayValue = Array.isArray(value)
          ? value.join(", ")
          : value || "";
        return `<textarea name="${fieldName}" id="${fieldId}" rows="3" class="ruby_cms-textarea block w-full rounded-md border border-gray-300 px-3 py-2 font-mono text-sm" placeholder="Comma-separated values or JSON array">${this.escapeHtml(arrayValue)}</textarea>`;
      case "object":
        const objectValue =
          typeof value === "object"
            ? JSON.stringify(value, null, 2)
            : value || "{}";
        return `<textarea name="${fieldName}" id="${fieldId}" rows="6" class="ruby_cms-textarea block w-full rounded-md border border-gray-300 px-3 py-2 font-mono text-sm" placeholder="JSON object">${this.escapeHtml(objectValue)}</textarea>`;
      default:
        return `<input type="text" name="${fieldName}" id="${fieldId}" value="${this.escapeHtml(value)}" class="ruby_cms-input block w-full rounded-md border border-gray-300 px-3 py-2">`;
    }
  }

  renderJsonEditor(componentKey, currentProps, nodeId) {
    if (!this.hasPropsFormTarget) return;

    this.propsFormTarget.innerHTML = `
      <div class="mb-4">
        <h3 class="text-sm font-semibold text-gray-900">${componentKey}</h3>
        <p class="text-xs text-gray-500 mt-1">No schema available. Edit as JSON.</p>
      </div>
      <form data-action="submit->ruby-cms--page-builder#saveNodeProps">
        <input type="hidden" name="node_id" value="${nodeId}">
        <div class="space-y-4">
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Props (JSON)</label>
            <textarea name="props" rows="8" class="w-full border border-gray-300 rounded px-3 py-2 font-mono text-sm">${JSON.stringify(currentProps, null, 2)}</textarea>
          </div>
          <button type="submit" class="ruby_cms-btn ruby_cms-btn-primary w-full">Save</button>
        </div>
      </form>
    `;
  }

  escapeHtml(text) {
    const div = document.createElement("div");
    div.textContent = text;
    return div.innerHTML;
  }

  async saveNodeProps(event) {
    event.preventDefault();
    const formData = new FormData(event.target);
    const nodeId = formData.get("node_id");

    // Get all checkbox inputs to handle unchecked state
    const checkboxes = event.target.querySelectorAll('input[type="checkbox"]');
    const uncheckedCheckboxes = new Set();
    checkboxes.forEach((cb) => {
      const match = cb.name.match(/props\[(.+)\]/);
      if (match && !cb.checked) {
        uncheckedCheckboxes.add(match[1]);
      }
    });

    // Build props object from form data
    const props = {};
    for (const [key, value] of formData.entries()) {
      if (key.startsWith("props[")) {
        const propKey = key.match(/props\[(.+)\]/)?.[1];
        if (propKey) {
          // Try to parse as JSON for complex types, otherwise use as string
          try {
            props[propKey] = JSON.parse(value);
          } catch {
            // Handle checkboxes
            if (value === "1") {
              props[propKey] = true;
            } else if (value === "") {
              props[propKey] = false;
            } else {
              // Try to parse arrays (comma-separated)
              if (value.includes(",") && !value.trim().startsWith("[")) {
                props[propKey] = value
                  .split(",")
                  .map((v) => v.trim())
                  .filter((v) => v);
              } else {
                props[propKey] = value;
              }
            }
          }
        }
      }
    }

    // Add unchecked checkboxes as false
    uncheckedCheckboxes.forEach((propKey) => {
      if (!(propKey in props)) {
        props[propKey] = false;
      }
    });

    const pageId = this.getPageId();
    if (!pageId) return;

    try {
      const response = await fetch(
        `${this.apiBase()}/nodes/${nodeId}?page_id=${pageId}`,
        {
          method: "PATCH",
          headers: {
            "Content-Type": "application/json",
            Accept: "application/json",
            "X-CSRF-Token": this.csrfTokenValue,
          },
          body: JSON.stringify({
            node: { props: props },
          }),
        },
      );

      const data = await this.parseJsonResponse(response);
      if (data.success) {
        // Show subtle success feedback
        const btn = event.target.querySelector('button[type="submit"]');
        if (btn) {
          const originalText = btn.textContent;
          btn.textContent = "Saved ✓";
          btn.style.background = "#10b981";
          setTimeout(() => {
            btn.textContent = originalText;
            btn.style.background = "";
          }, 2000);
        }

        // Refresh the node display if it has updated props
        const nodeElement = this.element.querySelector(
          `[data-node-id="${nodeId}"]`,
        );
        if (nodeElement && data.node) {
          // Update preview text if available
          const previewText = nodeElement.querySelector(
            ".ruby_cms-node-preview-text",
          );
          const props = data.node.props || {};
          const displayText =
            props.text || props.title || props.heading || props.content || "";
          if (previewText && displayText) {
            previewText.textContent = displayText.substring(0, 30);
          } else if (displayText && !previewText) {
            const nameSpan = nodeElement.querySelector(".ruby_cms-node-name");
            if (nameSpan) {
              const newPreview = document.createElement("span");
              newPreview.className = "ruby_cms-node-preview-text";
              newPreview.textContent = displayText.substring(0, 30);
              nameSpan.parentNode.appendChild(newPreview);
            }
          }
        }
      } else {
        alert(
          "Failed to save: " + (data.errors || ["Unknown error"]).join(", "),
        );
      }
    } catch (error) {
      logError("Error saving node props:", error);
      alert("Error saving properties. Please try again.");
    }
  }

  editNode(event) {
    event?.stopPropagation?.();

    // Get node ID from button's data attribute or parent node
    const button = event?.currentTarget;
    if (!button) return;

    const nodeId = button.dataset?.nodeId;
    const nodeElement = nodeId
      ? this.element.querySelector(`[data-node-id="${nodeId}"]`)
      : button.closest("[data-node-id]");

    if (!nodeElement) return;

    this.selectNode({ currentTarget: nodeElement });
  }

  async deleteNode(event) {
    event?.stopPropagation?.();

    // Get node ID from button's data attribute or parent node
    const button = event?.currentTarget;
    if (!button) return;

    // Get nodeId - try from button first, then from parent
    const nodeId =
      button.dataset?.nodeId ||
      button.closest("[data-node-id]")?.dataset?.nodeId;
    if (!nodeId) return;

    // Find the node element to remove later
    const nodeElement = this.element.querySelector(
      `[data-node-id="${nodeId}"]`,
    );
    if (!nodeElement) return;

    if (!confirm("Delete this component?")) return;

    const pageId = this.getPageId();
    if (!pageId) return;

    try {
      const response = await fetch(
        `${this.apiBase()}/nodes/${nodeId}?page_id=${pageId}`,
        {
          method: "DELETE",
          headers: {
            Accept: "application/json",
            "X-CSRF-Token": this.csrfTokenValue,
          },
        },
      );

      const data = await this.parseJsonResponse(response);
      if (data.success) {
        nodeElement.remove();
        if (this.hasPropsEditorTarget) {
          this.propsEditorTarget.classList.add("hidden");
        }
      } else {
        alert("Failed to delete component");
      }
    } catch (error) {
      logError("Error deleting node:", error);
      alert("Error deleting component. Please try again.");
    }
  }

  async createRegion(event) {
    const pageId = this.getPageId() || event.currentTarget?.dataset?.pageId;
    if (!pageId) {
      alert("No page selected");
      return;
    }

    const regionKey = prompt("Enter region key (e.g. 'main', 'sidebar'):");
    if (!regionKey) return;

    try {
      const response = await fetch(
        `${this.apiBase()}/regions?page_id=${pageId}`,
        {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            Accept: "application/json",
            "X-CSRF-Token": this.csrfTokenValue,
          },
          body: JSON.stringify({
            region: { key: regionKey },
          }),
        },
      );

      const data = await this.parseJsonResponse(response);
      if (data.success) {
        location.reload(); // Reload to show new region
      } else {
        alert(
          "Failed to create region: " +
            (data.errors || "Unknown error").join(", "),
        );
      }
    } catch (error) {
      logError("Error creating region:", error);
      alert("Error creating region. Please try again.");
    }
  }

  showComponentPicker(event) {
    // TODO: Show component picker modal
    alert("Component picker coming soon!");
  }

  async moveNode(nodeId, targetRegionKey, targetParentId = null) {
    const pageId = this.getPageId();
    if (!pageId) return;

    try {
      // Update the node's parent and region
      const response = await fetch(
        `${this.apiBase()}/nodes/${nodeId}?page_id=${pageId}`,
        {
          method: "PATCH",
          headers: {
            "Content-Type": "application/json",
            Accept: "application/json",
            "X-CSRF-Token": this.csrfTokenValue,
          },
          body: JSON.stringify({
            node: {
              parent_id: targetParentId,
            },
            region_key: targetRegionKey,
          }),
        },
      );

      const data = await this.parseJsonResponse(response);
      if (data.success) {
        // Reload page to reflect new structure
        location.reload();
      } else {
        alert(
          "Failed to move node: " +
            (data.errors || ["Unknown error"]).join(", "),
        );
      }
    } catch (error) {
      logError("Error moving node:", error);
      alert("Error moving component. Please try again.");
    }
  }

  async saveTree(regionKey) {
    const pageId = this.getPageId();
    if (!pageId) return;

    // Build tree structure from DOM
    const region = this.regionTargets.find(
      (r) => r.dataset.regionKey === regionKey,
    );
    if (!region) return;

    const nodesContainer = region.querySelector(
      "[data-ruby-cms--page-builder-target='regionNodes']",
    );
    if (!nodesContainer) return;

    const tree = this.buildTreeFromDOM(nodesContainer);

    try {
      const response = await fetch(
        `${this.apiBase()}/nodes/reorder?page_id=${pageId}`,
        {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            Accept: "application/json",
            "X-CSRF-Token": this.csrfTokenValue,
          },
          body: JSON.stringify({
            region_key: regionKey,
            tree: tree,
          }),
        },
      );

      const data = await this.parseJsonResponse(response);
      if (data.success) {
        alert("Page structure saved!");
      } else {
        alert("Failed to save: " + (data.errors || "Unknown error").join(", "));
      }
    } catch (error) {
      logError("Error saving tree:", error);
      alert("Error saving page structure. Please try again.");
    }
  }

  buildTreeFromDOM(container) {
    const tree = [];
    const nodes = container.querySelectorAll(
      "[data-node-id]:not([data-node-id] [data-node-id])",
    );

    nodes.forEach((nodeEl, index) => {
      const nodeId = parseInt(nodeEl.dataset.nodeId);
      const childrenContainer = nodeEl.querySelector(
        "[data-ruby-cms--page-builder-target='nodeChildren']",
      );

      const nodeData = {
        id: nodeId,
        children: childrenContainer
          ? this.buildTreeFromDOM(childrenContainer)
          : [],
      };

      tree.push(nodeData);
    });

    return tree;
  }

  save(event) {
    // Save all regions' tree structures
    this.regionTargets.forEach((region) => {
      this.saveTree(region.dataset.regionKey);
    });
  }

  // Helper to convert snake_case or camelCase to human-readable label
  humanize(str) {
    return str
      .replace(/_/g, " ")
      .replace(/([a-z])([A-Z])/g, "$1 $2")
      .replace(/\b\w/g, (char) => char.toUpperCase());
  }
}
