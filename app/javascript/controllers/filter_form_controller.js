import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  submit() {
    clearTimeout(this.timeout)
    this.element.requestSubmit()
  }

  debouncedSubmit() {
    clearTimeout(this.timeout)
    this.timeout = setTimeout(() => {
      this.element.requestSubmit()
    }, 300)
  }

  reset() {
    this.element.reset()
    this.element.requestSubmit()
  }
}
