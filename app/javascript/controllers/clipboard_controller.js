import { Controller } from "@hotwired/stimulus"

// Reveals and copies a value (e.g. an email) to the clipboard on click.
export default class extends Controller {
  static targets = ["masked", "button", "feedback"]
  static values = { full: String }

  copy(event) {
    event.preventDefault()
    if (!this.hasFullValue) return

    if (navigator.clipboard?.writeText) {
      navigator.clipboard.writeText(this.fullValue).catch(() => {})
    }

    if (this.hasMaskedTarget) this.maskedTarget.textContent = this.fullValue
    this.showFeedback()
  }

  showFeedback() {
    if (!this.hasFeedbackTarget) return

    this.feedbackTarget.classList.remove("hidden")
    window.clearTimeout(this.timeout)
    this.timeout = window.setTimeout(() => {
      this.feedbackTarget.classList.add("hidden")
    }, 1500)
  }

  disconnect() {
    window.clearTimeout(this.timeout)
  }
}
