import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["card", "pill", "tab", "panel", "pillFraction", "pricingModal"]
  static values = {
    activeTab: { type: String, default: "professional" },
    defaultCollapsed: { type: Boolean, default: true },
    forceCollapsed: { type: Boolean, default: false },
    actorId: { type: String, default: "default" }
  }

  connect() {
    // 1. Check if the widget was dismissed by user
    if (this.isDismissed()) {
      this.element.classList.add("hidden")
      return
    }

    // 2. Check saved role/tab preference
    const savedRole = this.readStorage(this.roleStorageKey)
    if (savedRole === "professional" || savedRole === "contractor") {
      this.activeTabValue = savedRole
    }
    this.applyTab(this.activeTabValue)

    // 3. Check status: start closed by default; only expand if user previously explicitly opened it
    const savedCollapsed = this.readStorage(this.collapsedStorageKey)
    const shouldExpand = !this.forceCollapsedValue && savedCollapsed === "false"

    this.applyCollapse(!shouldExpand)
  }

  switchTab(event) {
    const role = event.currentTarget.dataset.role
    if (!role) return

    this.activeTabValue = role
    this.writeStorage(this.roleStorageKey, role)
    this.applyTab(role)
  }

  collapse() {
    this.writeStorage(this.collapsedStorageKey, "true")
    this.applyCollapse(true)
  }

  expand() {
    this.writeStorage(this.collapsedStorageKey, "false")
    this.applyCollapse(false)
  }

  toggleCollapse() {
    const isCurrentlyCollapsed = this.cardTarget.classList.contains("hidden")
    if (isCurrentlyCollapsed) {
      this.expand()
    } else {
      this.collapse()
    }
  }

  dismiss() {
    this.writeStorage(this.dismissedStorageKey, "true")
    this.element.classList.add("opacity-0", "translate-y-2", "pointer-events-none")
    setTimeout(() => {
      this.element.classList.add("hidden")
    }, 200)
  }

  openPricingModal(event) {
    if (event) event.preventDefault()
    if (!this.hasPricingModalTarget) return

    this.pricingModalTarget.classList.remove("hidden")
    if (window.initLucide) window.initLucide()
  }

  closePricingModal(event) {
    if (event) event.preventDefault()
    if (!this.hasPricingModalTarget) return

    this.pricingModalTarget.classList.add("hidden")
  }

  applyTab(role) {
    this.tabTargets.forEach((tab) => {
      const isSelected = tab.dataset.role === role
      tab.setAttribute("aria-selected", isSelected ? "true" : "false")
      tab.classList.toggle("border-charcoal", isSelected)
      tab.classList.toggle("text-charcoal", isSelected)
      tab.classList.toggle("font-semibold", isSelected)
      tab.classList.toggle("border-transparent", !isSelected)
      tab.classList.toggle("text-zinc-500", !isSelected)
      tab.classList.toggle("font-medium", !isSelected)
    })

    this.panelTargets.forEach((panel) => {
      const isActive = panel.dataset.role === role
      panel.classList.toggle("hidden", !isActive)
      if (isActive && this.hasPillFractionTarget && panel.dataset.fraction) {
        this.pillFractionTarget.textContent = panel.dataset.fraction
      }
    })
  }

  applyCollapse(collapsed) {
    if (this.hasCardTarget && this.hasPillTarget) {
      this.cardTarget.classList.toggle("hidden", collapsed)
      this.pillTarget.classList.toggle("hidden", !collapsed)
    }
  }

  isDismissed() {
    return this.readStorage(this.dismissedStorageKey) === "true"
  }

  get dismissedStorageKey() {
    return `guilda:onboarding:dismissed:${this.actorIdValue}`
  }

  get collapsedStorageKey() {
    return `guilda:onboarding:collapsed:${this.actorIdValue}`
  }

  get roleStorageKey() {
    return `guilda:onboarding:role:${this.actorIdValue}`
  }

  readStorage(key) {
    try {
      const localVal = window.localStorage.getItem(key)
      if (localVal !== null) return localVal
      return window.sessionStorage.getItem(key)
    } catch {
      return null
    }
  }

  writeStorage(key, value) {
    try {
      window.localStorage.setItem(key, value)
    } catch {
      try {
        window.sessionStorage.setItem(key, value)
      } catch {
        // Ignore storage restrictions
      }
    }
  }
}
