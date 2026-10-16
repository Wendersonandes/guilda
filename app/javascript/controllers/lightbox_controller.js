import { Controller } from "@hotwired/stimulus"

// Fullscreen image lightbox for the project gallery. Opened from a thumbnail button with
// `data-lightbox-index-param`; supports keyboard navigation, Escape, backdrop click and focus
// management (traps focus while open and restores it on close).
export default class extends Controller {
  static targets = ["overlay", "image", "counter", "close"]
  static values = {
    images: Array,
    index: Number,
    counterTemplate: { type: String, default: "%{current} de %{total}" }
  }

  open(event) {
    if (!this.hasOverlayTarget || !this.imagesValue.length) return

    const index = parseInt(event.params.index, 10)
    this.previousFocus = document.activeElement
    this.indexValue = Number.isNaN(index) ? 0 : index

    this.overlayTarget.classList.remove("hidden")
    document.body.classList.add("overflow-hidden")

    this.onKeydown = (keyboardEvent) => this.handleKeydown(keyboardEvent)
    document.addEventListener("keydown", this.onKeydown)

    this.render()
    this.closeTarget.focus()
  }

  close() {
    if (!this.hasOverlayTarget) return

    this.overlayTarget.classList.add("hidden")
    document.body.classList.remove("overflow-hidden")
    document.removeEventListener("keydown", this.onKeydown)
    this.previousFocus?.focus?.()
  }

  next() {
    this.move(1)
  }

  previous() {
    this.move(-1)
  }

  move(step) {
    const count = this.imagesValue.length
    this.indexValue = (this.indexValue + step + count) % count
  }

  indexValueChanged() {
    if (this.hasOverlayTarget && !this.overlayTarget.classList.contains("hidden")) this.render()
  }

  render() {
    const url = this.imagesValue[this.indexValue]
    if (url && this.hasImageTarget) this.imageTarget.src = url

    if (this.hasCounterTarget) {
      this.counterTarget.textContent = this.counterTemplateValue
        .replace("%{current}", this.indexValue + 1)
        .replace("%{total}", this.imagesValue.length)
    }
  }

  handleKeydown(event) {
    if (event.key === "Escape") {
      event.preventDefault()
      this.close()
    } else if (event.key === "ArrowRight") {
      event.preventDefault()
      this.next()
    } else if (event.key === "ArrowLeft") {
      event.preventDefault()
      this.previous()
    } else if (event.key === "Tab") {
      this.trapFocus(event)
    }
  }

  trapFocus(event) {
    const scope = this.hasOverlayTarget ? this.overlayTarget : this.element
    const focusable = Array.from(scope.querySelectorAll("button:not([disabled])"))
    if (!focusable.length) return

    const first = focusable[0]
    const last = focusable[focusable.length - 1]

    if (event.shiftKey && document.activeElement === first) {
      event.preventDefault()
      last.focus()
    } else if (!event.shiftKey && document.activeElement === last) {
      event.preventDefault()
      first.focus()
    }
  }

  backdrop(event) {
    if (event.target === this.overlayTarget) this.close()
  }

  disconnect() {
    document.removeEventListener("keydown", this.onKeydown)
    document.body.classList.remove("overflow-hidden")
  }
}
