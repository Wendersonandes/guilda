import { Controller } from "@hotwired/stimulus"
import Sortable from "sortablejs"

// Makes the element's children reorderable via drag-and-drop. When `url` is set it persists the
// new order by PATCHing the ordered list of `[data-id]` values. It always emits a `sortable:end`
// event (with the new `ids`) so consumers can react to the reorder without persisting it.
export default class extends Controller {
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
    })
  }

  orderedIds() {
    return Array.from(this.element.children)
      .map((child) => child.dataset.id)
      .filter(Boolean)
  }
}
