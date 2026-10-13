import { Controller } from "@hotwired/stimulus"

// Formats a Brazilian mobile number as the user types: (DD) XXXXX-XXXX.
// Accepts an optional "55" country code, which is dropped.
export default class extends Controller {
  connect() {
    this.format()
  }

  format() {
    let digits = this.element.value.replace(/\D/g, "")
    if (digits.length > 11 && digits.startsWith("55")) digits = digits.slice(2)
    digits = digits.slice(0, 11)

    let formatted = digits
    if (digits.length > 2) formatted = `(${digits.slice(0, 2)}) ${digits.slice(2)}`
    if (digits.length > 7) formatted = `(${digits.slice(0, 2)}) ${digits.slice(2, 7)}-${digits.slice(7)}`

    this.element.value = formatted
  }
}
