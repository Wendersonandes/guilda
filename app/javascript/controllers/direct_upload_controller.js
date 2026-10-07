import { Controller } from "@hotwired/stimulus"

// Wraps an Active Storage direct-upload file input: shows a local preview of the
// selected image and a progress bar driven by the `direct-upload:*` events.
export default class extends Controller {
  static targets = ["input", "preview", "placeholder", "progress", "bar", "error"]

  connect() {
    this.onChange = this.onChange.bind(this)
    this.onProgress = this.onProgress.bind(this)
    this.onStart = this.onStart.bind(this)
    this.onEnd = this.onEnd.bind(this)
    this.onError = this.onError.bind(this)

    this.inputTarget.addEventListener("change", this.onChange)
    this.inputTarget.addEventListener("direct-upload:start", this.onStart)
    this.inputTarget.addEventListener("direct-upload:progress", this.onProgress)
    this.inputTarget.addEventListener("direct-upload:end", this.onEnd)
    this.inputTarget.addEventListener("direct-upload:error", this.onError)
  }

  disconnect() {
    this.inputTarget.removeEventListener("change", this.onChange)
    this.inputTarget.removeEventListener("direct-upload:start", this.onStart)
    this.inputTarget.removeEventListener("direct-upload:progress", this.onProgress)
    this.inputTarget.removeEventListener("direct-upload:end", this.onEnd)
    this.inputTarget.removeEventListener("direct-upload:error", this.onError)

    this.revokeObjectURL()
  }

  onChange() {
    const file = this.inputTarget.files?.[0]
    this.clearError()
    if (!file) return

    this.revokeObjectURL()
    this.objectUrl = URL.createObjectURL(file)

    if (this.hasPreviewTarget) {
      this.previewTarget.src = this.objectUrl
      this.previewTarget.classList.remove("hidden")
    }
    if (this.hasPlaceholderTarget) this.placeholderTarget.classList.add("hidden")

    this.showProgress()
    this.setBar(0)
  }

  onStart() {
    this.showProgress()
    this.setBar(0)
  }

  onProgress(event) {
    this.setBar(event.detail.progress)
  }

  onEnd() {
    this.setBar(100)
    window.setTimeout(() => this.hideProgress(), 400)
  }

  onError(event) {
    event.target.setCustomValidity?.("Upload failed. Please try again.")
    this.hideProgress()
    if (this.hasErrorTarget) {
      this.errorTarget.textContent = "Upload failed. Please try again."
      this.errorTarget.classList.remove("hidden")
    }
  }

  clearError() {
    if (this.hasErrorTarget) {
      this.errorTarget.textContent = ""
      this.errorTarget.classList.add("hidden")
    }
  }

  showProgress() {
    if (this.hasProgressTarget) this.progressTarget.classList.remove("hidden")
  }

  hideProgress() {
    if (this.hasProgressTarget) this.progressTarget.classList.add("hidden")
  }

  setBar(percent) {
    if (this.hasBarTarget) this.barTarget.style.width = `${percent}%`
  }

  revokeObjectURL() {
    if (this.objectUrl) {
      URL.revokeObjectURL(this.objectUrl)
      this.objectUrl = null
    }
  }
}
