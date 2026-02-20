import { Controller } from "@hotwired/stimulus"

// Makes the nav order list sortable via native HTML5 drag and drop.
// Shows a blue indicator line for drop position; supports dropping at the top.
export default class extends Controller {
  static values = {
    settingsUrl: { type: String, default: "/admin/settings/nav_order" }
  }

  connect() {
    this.list = this.element
    this.items = () => Array.from(this.list.querySelectorAll("[draggable='true']"))
    this.boundDragstart = this.dragstart.bind(this)
    this.boundDragend = this.dragend.bind(this)
    this.boundDragover = this.dragover.bind(this)
    this.boundDrop = this.drop.bind(this)
    this.boundDragleave = this.dragleave.bind(this)
    this.boundListDragover = this.listDragover.bind(this)
    this.boundListDrop = this.listDrop.bind(this)
    this.list.addEventListener("dragover", this.boundListDragover)
    this.list.addEventListener("drop", this.boundListDrop)
    this.list.addEventListener("dragleave", this.boundDragleave)
    this.items().forEach((item) => {
      item.addEventListener("dragstart", this.boundDragstart)
      item.addEventListener("dragend", this.boundDragend)
      item.addEventListener("dragover", this.boundDragover)
      item.addEventListener("dragleave", this.boundDragleave)
      item.addEventListener("drop", this.boundDrop)
    })
  }

  disconnect() {
    this.removeIndicator()
    this.list.removeEventListener("dragover", this.boundListDragover)
    this.list.removeEventListener("drop", this.boundListDrop)
    this.list.removeEventListener("dragleave", this.boundDragleave)
    this.items().forEach((item) => {
      item.removeEventListener("dragstart", this.boundDragstart)
      item.removeEventListener("dragend", this.boundDragend)
      item.removeEventListener("dragover", this.boundDragover)
      item.removeEventListener("dragleave", this.boundDragleave)
      item.removeEventListener("drop", this.boundDrop)
    })
  }

  getIndicator() {
    if (!this._indicator) {
      this._indicator = document.createElement("div")
      this._indicator.setAttribute("data-nav-order-indicator", "")
      this._indicator.className = "h-0.5 w-full bg-blue-500 flex-shrink-0 pointer-events-none"
      this._indicator.setAttribute("aria-hidden", "true")
    }
    return this._indicator
  }

  removeIndicator() {
    this._indicator?.remove()
    this._indicator = null
    this.dropIndex = null
    this.items().forEach((item) => item.classList.remove("ring-2", "ring-inset", "ring-blue-400"))
  }

  placeIndicator(insertIndex) {
    const items = this.items()
    if (insertIndex < 0 || insertIndex > items.length) return
    const indicator = this.getIndicator()
    if (insertIndex === 0) {
      this.list.insertBefore(indicator, items[0])
    } else {
      this.list.insertBefore(indicator, items[insertIndex])
    }
    this.dropIndex = insertIndex
  }

  dragleave(e) {
    // Only remove ring from items; indicator stays until drop/dragend or leave list
    if (e.currentTarget.getAttribute("draggable") === "true") {
      e.currentTarget.classList.remove("ring-2", "ring-inset", "ring-blue-400")
    }
    const list = this.list
    const related = e.relatedTarget
    if (!related || !list.contains(related)) {
      this.removeIndicator()
    }
  }

  dragstart(e) {
    this.dragged = e.currentTarget
    e.dataTransfer.effectAllowed = "move"
    e.dataTransfer.setData("text/html", e.currentTarget.innerHTML)
    e.currentTarget.classList.add("opacity-50")
  }

  dragend(e) {
    e.currentTarget.classList.remove("opacity-50")
    this.dragged = null
    this.removeIndicator()
    this.saveOrder()
  }

  listDragover(e) {
    if (!this.dragged) return
    e.preventDefault()
    e.dataTransfer.dropEffect = "move"
    const items = this.items()
    const first = items[0]
    if (!first) return
    const firstRect = first.getBoundingClientRect()
    if (e.clientY < firstRect.top + firstRect.height / 2) {
      this.placeIndicator(0)
    }
  }

  listDrop(e) {
    e.preventDefault()
    if (!this.dragged || this.dropIndex == null) return
    const items = this.items()
    const insertBefore = items[this.dropIndex]
    if (insertBefore && insertBefore !== this.dragged) {
      this.list.insertBefore(this.dragged, insertBefore)
    } else if (!insertBefore) {
      this.list.appendChild(this.dragged)
    }
    this.removeIndicator()
    this.saveOrder()
  }

  dragover(e) {
    e.preventDefault()
    e.dataTransfer.dropEffect = "move"
    const target = e.currentTarget
    if (target === this.dragged) return
    const items = this.items()
    const index = items.indexOf(target)
    if (index === -1) return
    const rect = target.getBoundingClientRect()
    const mid = rect.top + rect.height / 2
    const insertIndex = e.clientY < mid ? index : index + 1
    this.placeIndicator(insertIndex)
  }

  drop(e) {
    e.preventDefault()
    if (!this.dragged || this.dragged === e.currentTarget) return
    const items = this.items()
    const insertBefore = this.dropIndex != null ? items[this.dropIndex] : e.currentTarget.nextElementSibling
    if (insertBefore && insertBefore !== this.dragged) {
      this.list.insertBefore(this.dragged, insertBefore)
    } else if (!insertBefore) {
      this.list.appendChild(this.dragged)
    }
    this.removeIndicator()
    this.saveOrder()
  }

  saveOrder() {
    const form = this.element.closest("form")
    if (!form) return
    const mainList = form.querySelector("[data-list-type='main']")
    const bottomList = form.querySelector("[data-list-type='bottom']")
    const mainOrder = mainList ? Array.from(mainList.querySelectorAll("input[name='nav_order_main[]']")).map((i) => i.value) : []
    const bottomOrder = bottomList ? Array.from(bottomList.querySelectorAll("input[name='nav_order_bottom[]']")).map((i) => i.value) : []
    const url = this.settingsUrlValue || "/admin/settings/nav_order"
    const csrf = document.querySelector('meta[name="csrf-token"]')
    fetch(url, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": csrf ? csrf.content : "",
        Accept: "application/json"
      },
      body: JSON.stringify({
        tab: "navigation",
        nav_order_main: mainOrder,
        nav_order_bottom: bottomOrder
      })
    })
      .then((res) => (res.ok ? res.json() : Promise.reject(res)))
      .then(() => this.showToast("Order saved.", "success"))
      .catch(() => this.showToast("Failed to save order.", "error"))
  }

  showToast(message, type = "info") {
    const toast = document.createElement("div")
    toast.className = `fixed top-4 right-4 z-50 rounded-lg px-4 py-2.5 text-sm font-medium text-white shadow-lg ${
      type === "success" ? "bg-emerald-600" : type === "error" ? "bg-red-600" : "bg-gray-800"
    }`
    toast.textContent = message
    document.body.appendChild(toast)
    setTimeout(() => toast.remove(), 2500)
  }
}
