import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
    static targets = ["panel", "list"]
    static values = {
        contentBlockId: Number
    }

    connect() {
        this.isOpen = false
    }

    async toggle() {
        if (this.isOpen) {
            this.close()
        } else {
            await this.open()
        }
    }

    async open() {
        if (!this.contentBlockIdValue) return

        try {
            const response = await fetch(
                `/admin/content_blocks/${this.contentBlockIdValue}/versions.json`,
                { headers: { "Accept": "application/json" } }
            )
            if (!response.ok) throw new Error("Failed to fetch versions")

            const versions = await response.json()
            this.renderVersions(versions)
            this.panelTarget.classList.remove("hidden")
            this.isOpen = true
        } catch (error) {
            console.error("Error loading version history:", error)
        }
    }

    close() {
        this.panelTarget.classList.add("hidden")
        this.isOpen = false
    }

    renderVersions(versions) {
        if (!versions.length) {
            this.listTarget.innerHTML = '<p class="text-sm text-muted-foreground p-3">Geen versies gevonden.</p>'
            return
        }

        this.listTarget.innerHTML = versions.map(v => `
      <div class="flex items-center justify-between p-3 border-b border-border/40 last:border-0">
        <div>
          <span class="text-xs font-medium">v${v.version_number}</span>
          <span class="text-xs text-muted-foreground ml-1">${v.event}</span>
          <span class="text-xs text-muted-foreground ml-2">${v.user}</span>
          <span class="text-xs text-muted-foreground ml-2">${v.created_at}</span>
        </div>
        <button data-action="click->ruby-cms--content-block-history#rollback"
                data-version-id="${v.id}"
                class="text-xs text-primary hover:underline">
          Herstel
        </button>
      </div>
    `).join("")
    }

    async rollback(event) {
        const versionId = event.currentTarget.dataset.versionId
        if (!confirm("Weet je zeker dat je deze versie wilt herstellen?")) return

        try {
            const response = await fetch(
                `/admin/content_blocks/${this.contentBlockIdValue}/versions/${versionId}/rollback`,
                {
                    method: "POST",
                    headers: {
                        "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content,
                        "Accept": "application/json"
                    }
                }
            )
            if (!response.ok) throw new Error("Rollback failed")

            window.location.reload()
        } catch (error) {
            console.error("Rollback error:", error)
            alert("Rollback mislukt")
        }
    }
}