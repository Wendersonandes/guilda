import { Controller } from "@hotwired/stimulus"
import Sortable from "sortablejs"

// Makes the element's children reorderable via drag-and-drop and persists the new order by
// PATCHing `data-sortable-url-value` with the ordered list of `[data-id]` values.
export default class extends Controller {
  static values = { url: String, handle: String }

  connect() {
    this.sortable = Sortable.create(this.element, {
      animation: 150,
      handle: this.hasHandleValue ? this.handleValue : undefined,
      onEnd: () => this.persist()
    })
  }

  disconnect() {
    this.sortable?.destroy()
  }

  persist() {
    if (!this.hasUrlValue) return

    const ids = Array.from(this.element.children)
      .map((child) => child.dataset.id)
      .filter(Boolean)

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
}
