import { Controller } from "@hotwired/stimulus"

// Drives the new-project multi-step form: switches the visible step, marks the active tab and
// shows the final publish actions only on the last step.
export default class extends Controller {
  static targets = ["step", "tab", "previousButton", "nextButton", "submitActions"]
  static values = { index: { type: Number, default: 0 } }

  connect() {
    this.update()
  }

  goTo(event) {
    this.indexValue = parseInt(event.currentTarget.dataset.index, 10)
  }

  next() {
    if (this.indexValue < this.lastIndex) this.indexValue += 1
  }

  previous() {
    if (this.indexValue > 0) this.indexValue -= 1
  }

  preventEnter(event) {
    event.preventDefault()
  }

  indexValueChanged() {
    this.update()
  }

  get lastIndex() {
    return this.stepTargets.length - 1
  }

  update() {
    this.stepTargets.forEach((step, index) => {
      step.classList.toggle("hidden", index !== this.indexValue)
    })

    this.tabTargets.forEach((tab, index) => {
      const active = index === this.indexValue
      tab.classList.toggle("border-brand", active)
      tab.classList.toggle("text-brand", active)
      tab.classList.toggle("border-transparent", !active)
      tab.classList.toggle("text-zinc-500", !active)
    })

    this.previousButtonTarget.classList.toggle("hidden", this.indexValue === 0)
    this.nextButtonTarget.classList.toggle("hidden", this.indexValue === this.lastIndex)
    this.submitActionsTarget.classList.toggle("hidden", this.indexValue !== this.lastIndex)
  }
}
