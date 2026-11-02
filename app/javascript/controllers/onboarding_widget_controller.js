import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["cardWrapper", "card", "pill", "tab", "panel", "pillFraction", "pillCircle", "pricingModal"]
  static values = {
    activeTab: { type: String, default: "professional" },
    defaultCollapsed: { type: Boolean, default: true },
    forceCollapsed: { type: Boolean, default: false },
    actorId: { type: String, default: "default" },
    coolDownDays: { type: Number, default: 3 }
  }

  connect() {
    // 1. Check if the widget was dismissed by user within the cooldown period
    if (this.isDismissed()) {
      if (this.hasCardWrapperTarget) {
        this.cardWrapperTarget.classList.add("hidden")
      } else {
        this.element.classList.add("hidden")
      }
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
    const coolDownMs = this.coolDownDaysValue * 24 * 60 * 60 * 1000
    const dismissedUntil = Date.now() + coolDownMs
    this.writeStorage(this.dismissedStorageKey, dismissedUntil.toString())

    const target = this.hasCardWrapperTarget ? this.cardWrapperTarget : this.element
    target.classList.add("opacity-0", "translate-y-2", "pointer-events-none")
    setTimeout(() => {
      target.classList.add("hidden")
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
      if (isActive) {
        if (this.hasPillFractionTarget && panel.dataset.fraction) {
          this.pillFractionTarget.textContent = panel.dataset.fraction
        }
        if (this.hasPillCircleTarget && panel.dataset.dashOffset) {
          this.pillCircleTarget.setAttribute("stroke-dashoffset", panel.dataset.dashOffset)
        }
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
    const dismissedVal = this.readStorage(this.dismissedStorageKey)
    if (!dismissedVal) return false

    const expiry = parseInt(dismissedVal, 10)
    if (!isNaN(expiry)) {
      if (Date.now() < expiry) {
        return true
      }
      // Cooldown expired: remove key so it can be dismissed again with a fresh cooldown
      this.removeStorage(this.dismissedStorageKey)
      return false
    }

    return dismissedVal === "true"
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

  removeStorage(key) {
    try {
      window.localStorage.removeItem(key)
    } catch {
      // Ignore storage restrictions
    }
    try {
      window.sessionStorage.removeItem(key)
    } catch {
      // Ignore storage restrictions
    }
  }
}
