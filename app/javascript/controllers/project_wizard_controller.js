import { Controller } from "@hotwired/stimulus"

// Drives the new-project multi-step form: switches the visible step, marks the active tab and
// shows the final publish actions only on the last step.
export default class extends Controller {
  static targets = ["step", "tab", "previousButton", "nextButton", "submitActions", "stepIndicator"]
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
      const completed = index < this.indexValue

      tab.classList.toggle("border-charcoal", active)
      tab.classList.toggle("text-charcoal", active)
      tab.classList.toggle("font-semibold", active)

      tab.classList.toggle("border-stone-300", completed)
      tab.classList.toggle("text-zinc-700", completed)

      tab.classList.toggle("border-transparent", !active && !completed)
      tab.classList.toggle("text-zinc-400", !active && !completed)

      const badge = tab.querySelector("[data-badge]")
      if (badge) {
        if (active) {
          badge.className = "flex items-center justify-center w-5 h-5 rounded-full text-[10px] font-bold bg-charcoal text-white transition-colors"
        } else if (completed) {
          badge.className = "flex items-center justify-center w-5 h-5 rounded-full text-[10px] font-bold bg-stone-200 text-charcoal transition-colors"
        } else {
          badge.className = "flex items-center justify-center w-5 h-5 rounded-full text-[10px] font-bold bg-stone-100 text-zinc-400 transition-colors"
        }
      }
    })

    const isFirst = this.indexValue === 0
    const isLast = this.indexValue === this.lastIndex

    if (this.hasPreviousButtonTarget) {
      this.previousButtonTarget.classList.toggle("hidden", isFirst)
      this.previousButtonTarget.style.display = isFirst ? "none" : ""
    }

    if (this.hasNextButtonTarget) {
      this.nextButtonTarget.classList.toggle("hidden", isLast)
      this.nextButtonTarget.style.display = isLast ? "none" : ""
    }

    if (this.hasSubmitActionsTarget) {
      this.submitActionsTarget.classList.toggle("hidden", !isLast)
      this.submitActionsTarget.style.display = isLast ? "" : "none"
    }

    if (this.hasStepIndicatorTarget && this.tabTargets[this.indexValue]) {
      const stepTitle = this.tabTargets[this.indexValue].dataset.stepTitle || ""
      this.stepIndicatorTarget.textContent = `Etapa ${this.indexValue + 1} de ${this.lastIndex + 1}${stepTitle ? `: ${stepTitle}` : ""}`
    }
  }
}
