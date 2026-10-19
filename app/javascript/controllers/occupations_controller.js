import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["checkbox", "warning"]

  connect() {
    this.updateWarning()
  }

  toggle(event) {
    const checkedBoxes = this.checkboxTargets.filter(cb => cb.checked)
    const checkedCount = checkedBoxes.length

    if (checkedCount > 3) {
      event.preventDefault()
      event.target.checked = false // Guarantee the 4th is not selected visually
      this.showWarning()
    } else {
      this.updateWarning()
    }
  }

  showWarning() {
    this.warningTarget.classList.remove("hidden")
  }

  updateWarning() {
    this.warningTarget.classList.add("hidden")
  }
}
