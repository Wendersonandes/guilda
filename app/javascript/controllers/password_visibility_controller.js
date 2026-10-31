import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "icon"]

  connect() {
    this.visible = false
  }

  toggle(event) {
    event.preventDefault()
    this.visible = !this.visible

    if (this.hasInputTarget) {
      this.inputTarget.type = this.visible ? "text" : "password"
      this.inputTarget.focus()
    }

    if (this.hasIconTarget) {
      this.iconTarget.setAttribute("data-lucide", this.visible ? "eye-off" : "eye")
      if (window.lucide) {
        window.lucide.createIcons({
          root: this.element
        })
      }
    }

    const button = event.currentTarget
    if (button) {
      button.setAttribute("aria-label", this.visible ? "Ocultar senha" : "Ver senha")
      button.setAttribute("title", this.visible ? "Ocultar senha" : "Ver senha")
    }
  }
}
