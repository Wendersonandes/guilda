import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["country", "state", "city"]

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

  countryChanged(event) {
    fetch(`/locations/states?country=${event.target.value}`)
      .then((r) => r.text())
      .then((html) => {
        this.stateTarget.innerHTML = html
        this.reloadCities()
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
      fetch(`/locations/cities?state=${encodeURIComponent(state)}&country=${encodeURIComponent(country)}`)
        .then((r) => r.text())
        .then((html) => {
          if (this.hasCityTarget) {
            const currentCity = this.cityTarget.value
            this.cityTarget.innerHTML = html
            if (currentCity) {
              this.cityTarget.value = currentCity
            }
          }
        })
    } else if (this.hasCityTarget) {
      this.cityTarget.innerHTML = "<option value=''>Select</option>"
    }
  }
}
