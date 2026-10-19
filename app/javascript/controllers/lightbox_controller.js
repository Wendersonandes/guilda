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

    this.onTouchStart = (e) => this.handleTouchStart(e)
    this.onTouchEnd = (e) => this.handleTouchEnd(e)
    this.overlayTarget.addEventListener("touchstart", this.onTouchStart, { passive: true })
    this.overlayTarget.addEventListener("touchend", this.onTouchEnd, { passive: true })

    this.render()
    this.closeTarget.focus()
  }

  close() {
    if (!this.hasOverlayTarget) return

    this.overlayTarget.classList.add("hidden")
    document.body.classList.remove("overflow-hidden")
    document.removeEventListener("keydown", this.onKeydown)
    if (this.onTouchStart) {
      this.overlayTarget.removeEventListener("touchstart", this.onTouchStart)
      this.overlayTarget.removeEventListener("touchend", this.onTouchEnd)
    }
    this.resetImage()
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
    const item = this.imagesValue[this.indexValue]
    if (!item || !this.hasImageTarget) return

    const url = typeof item === "string" ? item : item.url
    const alt = typeof item === "string" ? "" : (item.alt || "")

    if (this.hasCounterTarget) {
      this.counterTarget.textContent = this.counterTemplateValue
        .replace("%{current}", this.indexValue + 1)
        .replace("%{total}", this.imagesValue.length)
    }

    this.imageTarget.alt = alt

    if (!url) return

    if (this.imageTarget.getAttribute("src") !== url) {
      this.imageTarget.classList.add("opacity-0")
      const onLoaded = () => {
        if (this.hasImageTarget && this.imageTarget.getAttribute("src") === url) {
          this.imageTarget.classList.remove("opacity-0")
        }
      }
      this.imageTarget.onload = onLoaded
      this.imageTarget.onerror = onLoaded
      this.imageTarget.src = url
      if (this.imageTarget.complete && this.imageTarget.naturalWidth > 0) {
        onLoaded()
      }
    } else {
      this.imageTarget.classList.remove("opacity-0")
    }
  }

  resetImage() {
    if (!this.hasImageTarget) return

    this.imageTarget.onload = null
    this.imageTarget.onerror = null
    this.imageTarget.classList.add("opacity-0")
    this.imageTarget.removeAttribute("src")
    this.imageTarget.alt = ""
  }

  handleTouchStart(event) {
    if (event.changedTouches && event.changedTouches.length > 0) {
      this.touchStartX = event.changedTouches[0].clientX
      this.touchStartY = event.changedTouches[0].clientY
    }
  }

  handleTouchEnd(event) {
    if (!event.changedTouches || event.changedTouches.length === 0 || this.touchStartX == null) return

    const diffX = event.changedTouches[0].clientX - this.touchStartX
    const diffY = event.changedTouches[0].clientY - this.touchStartY

    // Horizontal swipe threshold of 40px, dominating vertical scroll
    if (Math.abs(diffX) > 40 && Math.abs(diffX) > Math.abs(diffY)) {
      if (diffX > 0) {
        this.previous()
      } else {
        this.next()
      }
    }
    this.touchStartX = null
    this.touchStartY = null
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
    if (this.hasOverlayTarget && this.onTouchStart) {
      this.overlayTarget.removeEventListener("touchstart", this.onTouchStart)
      this.overlayTarget.removeEventListener("touchend", this.onTouchEnd)
    }
    this.resetImage()
    document.body.classList.remove("overflow-hidden")
  }
}
