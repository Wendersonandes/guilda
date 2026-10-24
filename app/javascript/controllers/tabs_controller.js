import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="tabs"
export default class extends Controller {
  static targets = ["tab", "panel"]
  static values = {
    defaultTab: { type: String, default: "" },
    activeClasses: { type: Array, default: ["border-charcoal", "text-charcoal", "font-semibold"] },
    inactiveClasses: { type: Array, default: ["border-transparent", "text-muted", "hover:text-charcoal", "hover:border-stone-300"] }
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

  keydown(event) {
    const tabs = this.tabTargets
    if (!tabs.length) return

    const currentIndex = tabs.indexOf(event.currentTarget)
    if (currentIndex === -1) return

    let nextIndex = null

    switch (event.key) {
      case "ArrowRight":
      case "ArrowDown":
        nextIndex = (currentIndex + 1) % tabs.length
        break
      case "ArrowLeft":
      case "ArrowUp":
        nextIndex = (currentIndex - 1 + tabs.length) % tabs.length
        break
      case "Home":
        nextIndex = 0
        break
      case "End":
        nextIndex = tabs.length - 1
        break
      default:
        return
    }

    event.preventDefault()
    const targetTab = tabs[nextIndex]
    const tabName = targetTab.dataset.tabName
    if (tabName) {
      this.selectTab(tabName)
      targetTab.focus()
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
