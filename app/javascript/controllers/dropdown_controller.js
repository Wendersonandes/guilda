import { Controller } from "@hotwired/stimulus"

// Toggles a dropdown menu. Closes on outside click and on Escape.
export default class extends Controller {
  static targets = ["menu", "button"]
  static values = { open: Boolean }

  connect() {
    this.openValue = false
  }

  toggle(event) {
    event.preventDefault()
    this.openValue ? this.close() : this.open()
  }

  open() {
    this.openValue = true
    this.menuTarget.classList.remove("hidden")
    this.buttonTarget.setAttribute("aria-expanded", "true")
  }

  close() {
    this.openValue = false
    this.menuTarget.classList.add("hidden")
    this.buttonTarget.setAttribute("aria-expanded", "false")
  }

  hideOnClickOutside(event) {
    if (!this.element.contains(event.target)) this.close()
  }

  hideOnEscape(event) {
    if (event.key === "Escape") this.close()
  }
}
