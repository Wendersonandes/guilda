import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "query",
    "results",
    "actorSlug",
    "actorName",
    "currentRolesContainer",
    "newRole",
    "detail",
    "form",
    "saveBtn"
  ]

  static values = {
    roles: Object,
    noRoleText: { type: String, default: "Sem papel especial atribuído" },
    noResultsText: { type: String, default: "Nenhum membro encontrado" },
    removeConfirmTemplate: { type: String, default: "Tem certeza de que deseja remover o papel de __ROLE__ de __NAME__?" },
    removeRoleText: { type: String, default: "Remover papel" },
    managedViaCliText: { type: String, default: "Gerenciado via console" },
    url: { type: String, default: "/actors.json" }
  }

  connect() {
    this.selectedActor = null
    this.abortController = null
    this.debounceTimer = null
    this.boundClickOutside = this.clickOutside.bind(this)
    document.addEventListener("click", this.boundClickOutside)
  }

  disconnect() {
    if (this.debounceTimer) clearTimeout(this.debounceTimer)
    if (this.abortController) this.abortController.abort()
    document.removeEventListener("click", this.boundClickOutside)
  }

  search() {
    const q = this.queryTarget.value.trim()

    if (this.debounceTimer) clearTimeout(this.debounceTimer)

    if (q.length < 2) {
      this.closeResults()
      this.detailTarget.classList.add("hidden")
      return
    }

    this.debounceTimer = setTimeout(() => {
      this.performSearch(q)
    }, 250)
  }

  performSearch(query) {
    if (this.abortController) this.abortController.abort()
    this.abortController = new AbortController()

    const searchUrl = `${this.urlValue}?q=${encodeURIComponent(query)}&include_site_roles=true`

    fetch(searchUrl, {
      signal: this.abortController.signal,
      headers: { "Accept": "application/json" }
    })
      .then((r) => r.json())
      .then((actors) => {
        this.renderResults(actors)
      })
      .catch((error) => {
        if (error.name !== "AbortError") {
          console.error("Role search failed:", error)
        }
      })
  }

  renderResults(actors) {
    this.resultsTarget.replaceChildren()

    if (actors.length === 0) {
      const emptyItem = document.createElement("p")
      emptyItem.className = "px-3.5 py-2.5 text-xs text-zinc-500 italic"
      emptyItem.textContent = this.noResultsTextValue
      this.resultsTarget.appendChild(emptyItem)
    } else {
      actors.forEach((a) => {
        const btn = document.createElement("button")
        btn.type = "button"
        btn.setAttribute("role", "option")
        btn.dataset.action = "click->role-search#select"
        btn.dataset.slug = a.slug
        btn.dataset.name = a.name
        btn.dataset.role = a.role
        btn.dataset.roles = JSON.stringify(a.roles || (a.role && a.role !== "none" ? [a.role] : []))
        btn.className = "w-full text-left px-3.5 py-2.5 text-xs hover:bg-stone-50 flex items-center gap-2.5 transition-colors cursor-pointer border-0 bg-transparent text-charcoal focus-visible:outline-none focus-visible:bg-stone-100"

        const avatarWrapper = document.createElement("div")
        avatarWrapper.className = "w-6 h-6 rounded-full bg-stone-100 border border-stone-200 overflow-hidden flex items-center justify-center text-[10px] font-semibold text-charcoal flex-shrink-0"

        if (a.avatar_url) {
          const img = document.createElement("img")
          img.src = a.avatar_url
          img.alt = ""
          img.className = "w-full h-full object-cover"
          avatarWrapper.appendChild(img)
        } else {
          avatarWrapper.textContent = (a.name || "?").charAt(0).toUpperCase()
        }

        const nameSpan = document.createElement("span")
        nameSpan.className = "font-medium text-charcoal truncate"
        nameSpan.textContent = a.name

        const rolesList = a.roles && a.roles.length > 0 ? a.roles : (a.role && a.role !== "none" ? [a.role] : [])
        const roleLabel = rolesList.length > 0
          ? rolesList.map(r => this.roleLabelFor(r)).join(", ")
          : this.noRoleTextValue

        const roleSpan = document.createElement("span")
        roleSpan.className = "text-[11px] text-zinc-500 ml-auto flex-shrink-0 max-w-[160px] truncate"
        roleSpan.textContent = roleLabel

        btn.appendChild(avatarWrapper)
        btn.appendChild(nameSpan)
        btn.appendChild(roleSpan)

        this.resultsTarget.appendChild(btn)
      })
    }

    this.resultsTarget.classList.remove("hidden")
    this.queryTarget.setAttribute("aria-expanded", "true")
  }

  select(event) {
    const btn = event.currentTarget
    this.selectedActor = btn.dataset.slug
    this.queryTarget.value = btn.dataset.name
    this.actorNameTarget.textContent = btn.dataset.name
    this.actorSlugTarget.value = btn.dataset.slug

    let roles = []
    try {
      roles = JSON.parse(btn.dataset.roles || "[]")
    } catch {
      roles = btn.dataset.role && btn.dataset.role !== "none" ? [btn.dataset.role] : []
    }

    this.renderCurrentRoles(roles, btn.dataset.name)

    const assignableRoles = Object.keys(this.hasRolesValue ? this.rolesValue : {})
      .filter(r => r !== "admin")
    const availableRole = assignableRoles.find(r => !roles.includes(r)) || "member"
    this.newRoleTarget.value = availableRole

    this.closeResults()
    this.detailTarget.classList.remove("hidden")
  }

  renderCurrentRoles(roles, actorName) {
    if (!this.hasCurrentRolesContainerTarget) return

    this.currentRolesContainerTarget.replaceChildren()

    if (roles.length === 0) {
      const span = document.createElement("span")
      span.className = "text-xs text-zinc-500 italic"
      span.textContent = this.noRoleTextValue
      this.currentRolesContainerTarget.appendChild(span)
      return
    }

    roles.forEach((role) => {
      if (role === "admin") {
        const badge = document.createElement("span")
        badge.className = "inline-flex items-center gap-1.5 text-xs font-medium px-2.5 py-1 rounded-md bg-stone-100 text-charcoal border border-stone-200"

        const label = document.createElement("span")
        label.textContent = this.roleLabelFor(role)
        badge.appendChild(label)

        const lockIcon = document.createElement("span")
        lockIcon.className = "inline-flex items-center text-zinc-400 ml-0.5"
        lockIcon.title = this.managedViaCliTextValue
        lockIcon.setAttribute("aria-label", this.managedViaCliTextValue)
        lockIcon.innerHTML = `<svg class="w-3 h-3" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect width="18" height="11" x="3" y="11" rx="2" ry="2"/><path d="M7 11V7a5 5 0 0 1 10 0v4"/></svg>`
        badge.appendChild(lockIcon)

        this.currentRolesContainerTarget.appendChild(badge)
        return
      }

      const badge = document.createElement("span")
      badge.className = "inline-flex items-center gap-1.5 text-xs font-medium px-2.5 py-1 rounded-md bg-stone-100 text-charcoal border border-stone-200"

      const label = document.createElement("span")
      label.textContent = this.roleLabelFor(role)
      badge.appendChild(label)

      const deleteForm = document.createElement("form")
      deleteForm.action = `/admin/roles/${encodeURIComponent(this.selectedActor)}`
      deleteForm.method = "post"
      deleteForm.className = "inline-flex items-center"

      const confirmMsg = this.removeConfirmTemplateValue
        .replace("__ROLE__", this.roleLabelFor(role))
        .replace("__NAME__", actorName)
      deleteForm.dataset.turboConfirm = confirmMsg

      const methodInput = document.createElement("input")
      methodInput.type = "hidden"
      methodInput.name = "_method"
      methodInput.value = "delete"
      deleteForm.appendChild(methodInput)

      const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content
      if (csrfToken) {
        const tokenInput = document.createElement("input")
        tokenInput.type = "hidden"
        tokenInput.name = "authenticity_token"
        tokenInput.value = csrfToken
        deleteForm.appendChild(tokenInput)
      }

      const roleInput = document.createElement("input")
      roleInput.type = "hidden"
      roleInput.name = "role"
      roleInput.value = role
      deleteForm.appendChild(roleInput)

      const delBtn = document.createElement("button")
      delBtn.type = "submit"
      delBtn.className = "text-zinc-400 hover:text-red-600 transition-colors p-0.5 ml-0.5 rounded cursor-pointer border-0 bg-transparent inline-flex items-center"
      delBtn.title = this.removeRoleTextValue
      delBtn.setAttribute("aria-label", `${this.removeRoleTextValue} ${this.roleLabelFor(role)} de ${actorName}`)
      delBtn.innerHTML = `<svg class="w-3.5 h-3.5" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M18 6 6 18"/><path d="m6 6 12 12"/></svg>`
      deleteForm.appendChild(delBtn)

      badge.appendChild(deleteForm)
      this.currentRolesContainerTarget.appendChild(badge)
    })
  }

  closeResults() {
    this.resultsTarget.classList.add("hidden")
    this.queryTarget.setAttribute("aria-expanded", "false")
  }

  clickOutside(event) {
    if (!this.element.contains(event.target)) {
      this.closeResults()
    }
  }

  handleKeydown(event) {
    if (event.key === "Escape") {
      this.closeResults()
    }
  }

  roleLabelFor(roleKey) {
    if (!roleKey || roleKey === "none") {
      return this.noRoleTextValue
    }
    const rolesMap = this.hasRolesValue ? this.rolesValue : {}
    return rolesMap[roleKey] || (roleKey.charAt(0).toUpperCase() + roleKey.slice(1))
  }
}
