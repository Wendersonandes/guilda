import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="signup-intent"
export default class extends Controller {
  static targets = [
    "tabProfessional",
    "tabContractor",
    "panelProfessional",
    "panelContractor",
    "planInput",
    "planOption",
    "planAnnual",
    "planMonthly",
    "checkAnnual",
    "checkMonthly",
    "submitButton",
    "submitNote",
    "googlePlanParam",
    "googleIntentParam",
    "nameLabel",
    "nameInput"
  ]

  static values = {
    selectedPlan: { type: String, default: "annual" },
    intent: { type: String, default: "professional" }
  }

  connect() {
    const urlParams = new URLSearchParams(window.location.search)
    const planParam = urlParams.get("plan")
    const intentParam = urlParams.get("intent")

    if (planParam === "none" || intentParam === "contractor") {
      this.setIntent("contractor")
    } else {
      if (planParam === "monthly" || planParam === "annual") {
        this.selectedPlanValue = planParam
      } else if (planParam === "trial") {
        this.selectedPlanValue = "annual"
      }
      this.setIntent("professional")
    }
  }

  selectProfessional(event) {
    if (event) event.preventDefault()
    this.setIntent("professional")
  }

  selectContractor(event) {
    if (event) event.preventDefault()
    this.setIntent("contractor")
  }

  selectAnnual(event) {
    if (event) event.preventDefault()
    this.selectPlan("annual")
  }

  selectMonthly(event) {
    if (event) event.preventDefault()
    this.selectPlan("monthly")
  }

  choosePlan(event) {
    if (event) event.preventDefault()
    const target = event.currentTarget.closest("[data-plan-id]") || event.target?.closest("[data-plan-id]") || event.currentTarget
    const planId = target?.getAttribute("data-plan-id") || target?.dataset?.planId
    if (planId) {
      this.selectPlan(planId)
    }
  }

  selectPlan(planId) {
    this.selectedPlanValue = planId
    this.updatePlanOptionsUI()
    this.updateFormFields()
  }

  setIntent(intent) {
    this.intentValue = intent

    const isProf = intent === "professional"

    if (this.hasTabProfessionalTarget) {
      this.toggleTabState(this.tabProfessionalTarget, isProf)
    }
    if (this.hasTabContractorTarget) {
      this.toggleTabState(this.tabContractorTarget, !isProf)
    }

    if (this.hasPanelProfessionalTarget) {
      this.panelProfessionalTarget.classList.toggle("hidden", !isProf)
    }
    if (this.hasPanelContractorTarget) {
      this.panelContractorTarget.classList.toggle("hidden", isProf)
    }

    if (this.hasSubmitButtonTarget) {
      this.submitButtonTarget.value = isProf
        ? "Criar conta e continuar"
        : "Criar conta gratuita"
    }

    if (this.hasSubmitNoteTarget) {
      this.submitNoteTarget.classList.toggle("hidden", !isProf)
    }

    if (this.hasNameLabelTarget) {
      this.nameLabelTarget.textContent = isProf
        ? "Nome profissional ou artístico"
        : "Seu nome ou nome da empresa/produtora"
    }

    if (this.hasNameInputTarget) {
      this.nameInputTarget.placeholder = isProf
        ? "Ex.: Ana Silva ou Estúdio Eixo"
        : "Ex.: Carlos Souza ou Produtora Aurora"
    }

    this.updatePlanOptionsUI()
    this.updateFormFields()
  }

  toggleTabState(button, active) {
    if (active) {
      button.classList.add("bg-charcoal", "text-white", "shadow-xs")
      button.classList.remove("text-zinc-600", "hover:text-charcoal", "bg-transparent")
      button.setAttribute("aria-selected", "true")
    } else {
      button.classList.remove("bg-charcoal", "text-white", "shadow-xs")
      button.classList.add("text-zinc-600", "hover:text-charcoal", "bg-transparent")
      button.setAttribute("aria-selected", "false")
    }
  }

  updatePlanOptionsUI() {
    const isAnnual = this.selectedPlanValue === "annual"

    if (this.hasPlanAnnualTarget) {
      this.setCardSelected(this.planAnnualTarget, isAnnual)
    }
    if (this.hasPlanMonthlyTarget) {
      this.setCardSelected(this.planMonthlyTarget, !isAnnual)
    }

    if (this.hasCheckAnnualTarget) {
      this.checkAnnualTarget.classList.toggle("hidden", !isAnnual)
    }
    if (this.hasCheckMonthlyTarget) {
      this.checkMonthlyTarget.classList.toggle("hidden", isAnnual)
    }

    if (this.hasPlanOptionTargets) {
      this.planOptionTargets.forEach(card => {
        const cardPlanId = card.getAttribute("data-plan-id") || card.dataset.planId
        const isSelected = cardPlanId === this.selectedPlanValue
        this.setCardSelected(card, isSelected)
        const checkIcon = card.querySelector("[data-check-icon]")
        if (checkIcon) checkIcon.classList.toggle("hidden", !isSelected)
      })
    }
  }

  setCardSelected(card, isSelected) {
    if (!card) return
    if (isSelected) {
      card.classList.remove("border-stone-200", "hover:border-stone-300")
      card.classList.add("border-brand", "ring-1", "ring-brand")
      card.setAttribute("aria-checked", "true")
    } else {
      card.classList.remove("border-brand", "ring-1", "ring-brand")
      card.classList.add("border-stone-200", "hover:border-stone-300")
      card.setAttribute("aria-checked", "false")
    }
  }

  updateFormFields() {
    const isProf = this.intentValue === "professional"
    const effectivePlan = isProf ? this.selectedPlanValue : "none"

    if (this.hasPlanInputTarget) {
      this.planInputTarget.value = effectivePlan
    }

    if (this.hasGooglePlanParamTarget) {
      this.googlePlanParamTarget.value = effectivePlan
    }

    if (this.hasGoogleIntentParamTarget) {
      this.googleIntentParamTarget.value = this.intentValue
    }
  }
}
