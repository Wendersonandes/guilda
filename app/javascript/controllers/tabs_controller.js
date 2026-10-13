import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="tabs"
export default class extends Controller {
  static targets = ["tab", "panel"]
  static values = {
    defaultTab: { type: String, default: "" },
    activeClasses: { type: Array, default: ["border-charcoal", "text-charcoal", "font-semibold"] },
    inactiveClasses: { type: Array, default: ["border-transparent", "text-zinc-500", "hover:text-charcoal", "hover:border-stone-300"] }
  }

  connect() {
    const initialTab = this.defaultTabValue || (this.tabTargets[0]?.dataset.tabName)
    if (initialTab) {
      this.selectTab(initialTab)
    }
  }

  change(event) {
    event.preventDefault()
    const tabName = event.currentTarget.dataset.tabName
    if (tabName) {
      this.selectTab(tabName)
    }
  }

  selectTab(tabName) {
    this.tabTargets.forEach(tab => {
      const isSelected = tab.dataset.tabName === tabName
      tab.setAttribute("aria-selected", isSelected ? "true" : "false")
      tab.setAttribute("tabindex", isSelected ? "0" : "-1")

      if (isSelected) {
        tab.classList.remove(...this.inactiveClassesValue)
        tab.classList.add(...this.activeClassesValue)
      } else {
        tab.classList.remove(...this.activeClassesValue)
        tab.classList.add(...this.inactiveClassesValue)
      }
    })

    this.panelTargets.forEach(panel => {
      const isMatch = panel.dataset.tabPanel === tabName
      if (isMatch) {
        panel.classList.remove("hidden")
        panel.removeAttribute("hidden")
      } else {
        panel.classList.add("hidden")
        panel.setAttribute("hidden", "true")
      }
    })
  }
}
