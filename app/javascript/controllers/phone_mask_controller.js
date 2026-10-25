import { Controller } from "@hotwired/stimulus"

// Formats a Brazilian mobile number as the user types: (DD) XXXXX-XXXX.
// Accepts an optional "55" country code, which is dropped.
export default class extends Controller {
  connect() {
    this.format()
  }

  format() {
    const input = this.element
    const cursor = input.selectionStart || 0
    const rawValue = input.value

    let digitsBeforeCursor = rawValue.slice(0, cursor).replace(/\D/g, "").length

    let digits = rawValue.replace(/\D/g, "")
    if (digits.length > 11 && digits.startsWith("55")) {
      digits = digits.slice(2)
      digitsBeforeCursor = Math.max(0, digitsBeforeCursor - 2)
    }
    digits = digits.slice(0, 11)

    let formatted = digits
    if (digits.length > 2) formatted = `(${digits.slice(0, 2)}) ${digits.slice(2)}`
    if (digits.length > 7) formatted = `(${digits.slice(0, 2)}) ${digits.slice(2, 7)}-${digits.slice(7)}`

    input.value = formatted

    if (document.activeElement === input) {
      let newCursor = 0
      let seenDigits = 0
      while (newCursor < formatted.length && seenDigits < digitsBeforeCursor) {
        if (/\d/.test(formatted[newCursor])) {
          seenDigits++
        }
        newCursor++
      }
      input.setSelectionRange(newCursor, newCursor)
    }
  }
}
