import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input"]
  static values = {
    delay: { type: Number, default: 500 }
  }

  connect() {
    this.previousQuery = this.queryInput?.value?.trim() ?? ""
  }

  disconnect() {
    clearTimeout(this.timeout)
  }

  submit() {
    clearTimeout(this.timeout)
    this.previousQuery = this.queryInput?.value?.trim() ?? ""
    this.element.requestSubmit()
  }

  debouncedSubmit(event) {
    clearTimeout(this.timeout)

    const currentQuery = (event?.target?.value ?? this.queryInput?.value ?? "").trim()

    // Do not submit if the query text hasn't actually changed
    if (currentQuery === this.previousQuery) {
      return
    }

    this.timeout = setTimeout(() => {
      this.previousQuery = currentQuery
      this.element.requestSubmit()
    }, this.delayValue)
  }

  reset() {
    clearTimeout(this.timeout)
    this.element.reset()
    this.previousQuery = ""
    this.element.requestSubmit()
  }

  get queryInput() {
    return this.hasInputTarget ? this.inputTarget : this.element.querySelector('input[name="q"]')
  }
}

