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
    "submitButton",
    "submitNote",
    "googlePlanParam",
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

  choosePlan(event) {
    if (event) event.preventDefault()
    const planId = event.currentTarget.dataset.planId
    if (planId) {
      this.selectedPlanValue = planId
      this.updatePlanOptionsUI()
      this.updateFormFields()
    }
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
    if (!this.hasPlanOptionTargets) return

    this.planOptionTargets.forEach(card => {
      const isSelected = card.dataset.planId === this.selectedPlanValue
      const checkIcon = card.querySelector("[data-check-icon]")

      if (isSelected) {
        card.classList.add("border-brand", "ring-1", "ring-brand")
        card.classList.remove("border-stone-200")
        if (checkIcon) checkIcon.classList.remove("hidden")
      } else {
        card.classList.remove("border-brand", "ring-1", "ring-brand")
        card.classList.add("border-stone-200")
        if (checkIcon) checkIcon.classList.add("hidden")
      }
    })
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
  }
}
