import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="dismissable"
export default class extends Controller {
  dismiss(event) {
    if (event) event.preventDefault()
    this.element.style.transition = "all 0.2s ease-out"
    this.element.style.opacity = "0"
    this.element.style.transform = "scale(0.98)"
    setTimeout(() => {
      this.element.remove()
    }, 200)
  }
}
