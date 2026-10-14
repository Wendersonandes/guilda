import { Controller } from "@hotwired/stimulus"

// Automatically dismisses flash/alert messages after a timeout (default 4s)
// with smooth exit transitions and manual close support.
export default class extends Controller {
  static values = {
    timeout: { type: Number, default: 4000 }
  }

  connect() {
    if (typeof lucide !== "undefined") {
      lucide.createIcons()
    }
    this.scheduleDismiss()
  }

  disconnect() {
    this.clearTimer()
  }

  scheduleDismiss() {
    if (this.timeoutValue > 0) {
      this.timer = setTimeout(() => {
        this.dismiss()
      }, this.timeoutValue)
    }
  }

  clearTimer() {
    if (this.timer) {
      clearTimeout(this.timer)
      this.timer = null
    }
  }

  pause() {
    this.clearTimer()
  }

  resume() {
    this.scheduleDismiss()
  }

  dismiss() {
    this.clearTimer()

    // Smooth fade out and collapse height
    this.element.classList.add("transition-all", "duration-300", "ease-out", "overflow-hidden")
    this.element.style.opacity = "0"
    this.element.style.transform = "translateY(-4px)"
    this.element.style.maxHeight = `${this.element.scrollHeight}px`

    requestAnimationFrame(() => {
      this.element.style.maxHeight = "0"
      this.element.style.marginTop = "0"
      this.element.style.marginBottom = "0"
      this.element.style.paddingTop = "0"
      this.element.style.paddingBottom = "0"
    })

    setTimeout(() => {
      this.element.remove()
    }, 320)
  }
}
