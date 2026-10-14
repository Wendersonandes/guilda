import { Controller } from "@hotwired/stimulus"

// Enhances styled dropzone file inputs with drag-and-drop handling
// and dynamic file selection feedback.
export default class extends Controller {
  static targets = ["input", "status"]

  connect() {
    if (typeof lucide !== "undefined") {
      lucide.createIcons()
    }
  }

  dragOver(event) {
    event.preventDefault()
    this.element.classList.add("border-charcoal", "bg-stone-100/70")
  }

  dragLeave(event) {
    event.preventDefault()
    this.element.classList.remove("border-charcoal", "bg-stone-100/70")
  }

  drop(event) {
    event.preventDefault()
    this.element.classList.remove("border-charcoal", "bg-stone-100/70")

    const files = event.dataTransfer?.files
    if (files?.length && this.hasInputTarget) {
      this.inputTarget.files = files
      this.inputTarget.dispatchEvent(new Event("change", { bubbles: true }))
      this.fileChanged()
    }
  }

  fileChanged() {
    if (!this.hasInputTarget || !this.hasStatusTarget) return

    const count = this.inputTarget.files?.length || 0
    if (count > 0) {
      const label = count === 1 ? "1 foto selecionada" : `${count} fotos selecionadas`
      this.statusTarget.textContent = label
      this.statusTarget.classList.remove("hidden")
    } else {
      this.statusTarget.classList.add("hidden")
    }
  }
}
