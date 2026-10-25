import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["country", "state", "city"]
  static values = {
    selectText: { type: String, default: "Selecione" },
    loadingText: { type: String, default: "Carregando cidades..." },
    errorText: { type: String, default: "Erro ao carregar cidades" }
  }

  connect() {
    if (
      this.hasStateTarget &&
      this.stateTarget.value &&
      this.hasCityTarget &&
      this.cityTarget.options.length <= 1
    ) {
      this.reloadCities()
    }
  }

  disconnect() {
    if (this.abortController) {
      this.abortController.abort()
    }
  }

  countryChanged(event) {
    fetch(`/locations/states?country=${event.target.value}`)
      .then((r) => {
        if (!r.ok) throw new Error("Network response was not ok")
        return r.text()
      })
      .then((html) => {
        this.stateTarget.innerHTML = html
        this.reloadCities()
      })
      .catch((error) => {
        console.error("Error loading states:", error)
      })
  }

  stateChanged() {
    this.reloadCities()
  }

  reloadCities() {
    const country =
      (this.hasCountryTarget && this.countryTarget.value) ||
      this.element.querySelector("[data-location-target='country']")?.value ||
      "BR"
    const state = this.hasStateTarget ? this.stateTarget.value : ""
    if (state) {
      if (this.abortController) {
        this.abortController.abort()
      }
      this.abortController = new AbortController()

      if (this.hasCityTarget) {
        this.cityTarget.setAttribute("aria-busy", "true")
        const currentCity = this.cityTarget.value
        this.cityTarget.innerHTML = `<option value="">${this.loadingTextValue}</option>`

        fetch(`/locations/cities?state=${encodeURIComponent(state)}&country=${encodeURIComponent(country)}`, {
          signal: this.abortController.signal
        })
          .then((r) => {
            if (!r.ok) throw new Error("Network response was not ok")
            return r.text()
          })
          .then((html) => {
            if (this.hasCityTarget) {
              this.cityTarget.removeAttribute("aria-busy")
              this.cityTarget.innerHTML = html
              if (currentCity) {
                this.cityTarget.value = currentCity
              }
            }
          })
          .catch((error) => {
            if (error.name !== "AbortError") {
              console.error("Error loading cities:", error)
              if (this.hasCityTarget) {
                this.cityTarget.removeAttribute("aria-busy")
                this.cityTarget.innerHTML = `<option value="">${this.errorTextValue}</option>`
              }
            }
          })
      }
    } else if (this.hasCityTarget) {
      const selectText = this.selectTextValue
      this.cityTarget.removeAttribute("aria-busy")
      this.cityTarget.innerHTML = `<option value=''>${selectText}</option>`
    }
  }
}
