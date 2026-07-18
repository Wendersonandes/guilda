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
      this.shakeSelected(checkedBoxes)
    } else {
      this.updateWarning()
    }
  }

  shakeSelected(checkedBoxes) {
    checkedBoxes.forEach(cb => {
      // The visual pill is the div right after the hidden checkbox (the peer element)
      const visualPill = cb.nextElementSibling
      if (visualPill) {
        visualPill.classList.remove("animate-shake")
        // Force reflow to restart animation on rapid clicks
        void visualPill.offsetWidth
        visualPill.classList.add("animate-shake")
        
        setTimeout(() => {
          visualPill.classList.remove("animate-shake")
        }, 400)
      }
    })
  }

  showWarning() {
    this.warningTarget.classList.remove("hidden")
    
    // Add a simple animation or highlight color if using tailwind classes
    this.warningTarget.classList.add("text-red-600", "font-medium")
    
    // Auto-hide after 3 seconds
    if (this.timeoutId) {
      clearTimeout(this.timeoutId)
    }
    
    this.timeoutId = setTimeout(() => {
      this.warningTarget.classList.add("hidden")
    }, 3000)
  }

  updateWarning() {
    this.warningTarget.classList.add("hidden")
  }
}
