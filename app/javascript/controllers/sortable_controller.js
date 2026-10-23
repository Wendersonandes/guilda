import { Controller } from "@hotwired/stimulus"
import Sortable from "sortablejs"

// Makes the element's children reorderable via drag-and-drop. When `url` is set it persists the
// new order by PATCHing the ordered list of `[data-id]` values. It always emits a `sortable:end`
// event (with the new `ids`) so consumers can react to the reorder without persisting it.
export default class extends Controller {
  static targets = [ "status" ]
  static values = { url: String, handle: String, filter: String }

  connect() {
    this.sortable = Sortable.create(this.element, {
      animation: 150,
      handle: this.hasHandleValue ? this.handleValue : undefined,
      filter: this.hasFilterValue ? this.filterValue : undefined,
      onEnd: () => this.end()
    })
  }

  disconnect() {
    this.sortable?.destroy()
  }

  handleKeydown(event) {
    if (event.key !== "ArrowUp" && event.key !== "ArrowDown") return

    const handle = event.currentTarget
    const item = handle.closest("[data-id]")
    if (!item) return

    if (event.key === "ArrowUp") {
      const prev = item.previousElementSibling
      if (prev && prev.hasAttribute("data-id")) {
        event.preventDefault()
        this.element.insertBefore(item, prev)
        handle.focus()
        this.end()
        this.announceMove(item)
      }
    } else if (event.key === "ArrowDown") {
      const next = item.nextElementSibling
      if (next && next.hasAttribute("data-id")) {
        event.preventDefault()
        this.element.insertBefore(next, item)
        handle.focus()
        this.end()
        this.announceMove(item)
      }
    }
  }

  announceMove(item) {
    const ids = this.orderedIds()
    const index = ids.indexOf(item.dataset.id)
    if (index === -1) return

    const statusEl = this.hasStatusTarget ? this.statusTarget : this.element.querySelector("[data-sortable-status]")
    if (statusEl) {
      statusEl.textContent = `Posição alterada para ${index + 1} de ${ids.length}.`
    }
  }

  end() {
    const ids = this.orderedIds()
    this.element.dispatchEvent(new CustomEvent("sortable:end", { bubbles: true, detail: { ids } }))

    if (!this.hasUrlValue) return

    fetch(this.urlValue, {
      method: "PATCH",
      headers: {
        "Content-Type": "application/json",
        "Accept": "application/json",
        "X-CSRF-Token": document.querySelector("meta[name=csrf-token]")?.content
      },
      body: JSON.stringify({ ids })
    }).then((response) => {
      if (!response.ok) {
        console.warn("Reorder request failed with status:", response.status)
      }
    }).catch((error) => {
      console.error("Reorder network error:", error)
    })
  }

  orderedIds() {
    return Array.from(this.element.children)
      .map((child) => child.dataset.id)
      .filter(Boolean)
  }
}
