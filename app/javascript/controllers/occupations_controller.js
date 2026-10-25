import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["checkbox", "warning", "counter"]
  static values = {
    max: { type: Number, default: 3 },
    counterTemplate: { type: String, default: "%{count} de 3 selecionadas" }
  }

  connect() {
    this.hideWarning()
    this.updateState()
  }

  toggle(event) {
    const count = this.checkedBoxes.length

    if (count > this.maxValue) {
      event.preventDefault()
      event.target.checked = false
      this.showWarning()
    } else {
      this.hideWarning()
    }

    this.updateState()
  }

  get checkedBoxes() {
    return this.checkboxTargets.filter(cb => cb.checked)
  }

  updateState() {
    const count = this.checkedBoxes.length
    if (this.hasCounterTarget) {
      this.counterTarget.textContent = this.counterTemplateValue.replace("%{count}", count)
    }

    const atLimit = count >= this.maxValue
    this.checkboxTargets.forEach(cb => {
      const label = cb.closest("label")
      if (label) {
        if (atLimit && !cb.checked) {
          label.classList.add("opacity-50")
        } else {
          label.classList.remove("opacity-50")
        }
      }
    })
  }

  showWarning() {
    if (this.hasWarningTarget) {
      this.warningTarget.classList.remove("hidden")
    }
  }

  hideWarning() {
    if (this.hasWarningTarget) {
      this.warningTarget.classList.add("hidden")
    }
  }

  updateWarning() {
    this.hideWarning()
  }
}
