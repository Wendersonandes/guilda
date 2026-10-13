import { Controller } from "@hotwired/stimulus"

// Mirrors the new-project form into the live preview (title, description, cover and gallery
// images). Images are previewed locally via object URLs until the form is submitted; the cover
// is chosen among the selected gallery images.
export default class extends Controller {
  static targets = [
    "titleInput", "galleryInput", "coverIndexInput", "thumbnails", "galleryEmpty",
    "titleText", "about", "aboutSection", "cover", "coverPlaceholder",
    "gallery", "gallerySection"
  ]

  connect() {
    this.urls = new Map()
    this.files = []
    this.selectedCoverIndex = null
    this.titlePlaceholder = this.hasTitleTextTarget ? this.titleTextTarget.textContent : ""

    this.editor = this.element.querySelector("lexxy-editor")
    if (this.editor) {
      this.onEditorChange = () => this.aboutChanged()
      this.editor.addEventListener("lexxy:change", this.onEditorChange)
    }

    this.titleChanged()
    this.aboutChanged()
    this.renderGallery()
  }

  disconnect() {
    if (this.editor && this.onEditorChange) this.editor.removeEventListener("lexxy:change", this.onEditorChange)
    this.revokeUrls()
  }

  titleChanged() {
    const value = (this.titleInputTarget.value || "").trim()
    this.titleTextTarget.textContent = value || this.titlePlaceholder
    this.titleTextTarget.classList.toggle("text-zinc-300", !value)
  }

  aboutChanged() {
    const html = this.editor ? this.editor.value : ""
    const empty = this.blankHtml(html)
    this.aboutTarget.innerHTML = empty ? "" : html
    this.aboutSectionTarget.classList.toggle("hidden", empty)
  }

  galleryChanged() {
    this.revokeUrls()
    this.files = Array.from(this.galleryInputTarget.files || [])
    this.selectedCoverIndex = null
    this.coverIndexInputTarget.value = ""
    this.renderGallery()
  }

  selectCover(event) {
    this.selectedCoverIndex = parseInt(event.currentTarget.dataset.index, 10)
    this.coverIndexInputTarget.value = this.selectedCoverIndex
    this.renderGallery()
  }

  renderGallery() {
    const hasFiles = this.files.length > 0

    if (this.hasGalleryEmptyTarget) this.galleryEmptyTarget.classList.toggle("hidden", hasFiles)

    this.thumbnailsTarget.innerHTML = ""
    this.files.forEach((file, index) => {
      const wrapper = document.createElement("div")
      wrapper.className = "relative rounded-lg overflow-hidden border border-stone-border"
      if (index === this.activeCoverIndex()) wrapper.classList.add("ring-2", "ring-brand")
      wrapper.innerHTML = `
        <img src="${this.urlFor(file)}" class="w-full h-24 object-cover" alt="">
        <button type="button" data-action="project-preview#selectCover" data-index="${index}"
                title="${this.coverLabel}" aria-label="${this.coverLabel}"
                class="absolute top-1 right-1 flex items-center justify-center w-6 h-6 rounded-full bg-black/50 text-white/90 hover:text-white cursor-pointer">
          <i data-lucide="star" class="w-3.5 h-3.5"></i>
        </button>`
      this.thumbnailsTarget.appendChild(wrapper)
    })
    if (window.initLucide) window.initLucide()

    this.galleryTarget.innerHTML = ""
    this.files.forEach((file) => {
      const img = document.createElement("img")
      img.src = this.urlFor(file)
      img.className = "w-full h-40 object-cover rounded-lg border border-stone-border"
      this.galleryTarget.appendChild(img)
    })
    this.gallerySectionTarget.classList.toggle("hidden", !hasFiles)

    this.updatePreviewCover()
  }

  updatePreviewCover() {
    const index = this.activeCoverIndex()
    const file = index === null ? null : this.files[index]

    if (file) {
      this.coverTarget.src = this.urlFor(file)
      this.coverTarget.classList.remove("hidden")
      this.coverPlaceholderTarget.classList.add("hidden")
    } else {
      this.coverTarget.classList.add("hidden")
      this.coverPlaceholderTarget.classList.remove("hidden")
    }
  }

  activeCoverIndex() {
    if (this.files.length === 0) return null
    return this.selectedCoverIndex === null ? 0 : this.selectedCoverIndex
  }

  get coverLabel() {
    return this.coverIndexInputTarget.dataset.coverLabel || ""
  }

  urlFor(file) {
    if (!this.urls.has(file)) this.urls.set(file, URL.createObjectURL(file))
    return this.urls.get(file)
  }

  revokeUrls() {
    this.urls.forEach((url) => URL.revokeObjectURL(url))
    this.urls.clear()
  }

  blankHtml(html) {
    const element = document.createElement("div")
    element.innerHTML = html || ""
    return element.textContent.trim() === ""
  }
}
