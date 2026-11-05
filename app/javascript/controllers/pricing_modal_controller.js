import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["modal"]

  open(event) {
    if (event) event.preventDefault()
    if (!this.hasModalTarget) return

    this.modalTarget.classList.remove("hidden")
    document.body.classList.add("overflow-hidden")
    if (window.initLucide) window.initLucide()
  }

  close(event) {
    if (event) event.preventDefault()
    if (!this.hasModalTarget) return

    this.modalTarget.classList.add("hidden")
    document.body.classList.remove("overflow-hidden")
  }

  closeWithKeyboard(event) {
    if (event.key === "Escape") {
      this.close(event)
    }
  }

  disconnect() {
    document.body.classList.remove("overflow-hidden")
  }
}
