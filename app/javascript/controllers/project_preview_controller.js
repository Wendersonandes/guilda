import { Controller } from "@hotwired/stimulus"

// Mirrors the new-project form into the live preview (title, description, cover and gallery
// images). Images are previewed locally via object URLs until the form is submitted; the cover
// is marked among the selected gallery images (falling back to the first when none is marked).
export default class extends Controller {
  static targets = [
    "titleInput", "galleryInput", "coverIndexInput", "thumbnails", "galleryEmpty",
    "titleText", "about", "aboutSection", "cover", "coverPlaceholder",
    "gallery", "gallerySection"
  ]

  connect() {
    this.urls = new Map()
    this.files = []
    this.coverFile = null
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
    this.coverFile = null
    this.renderGallery()
  }

  selectCover(event) {
    const file = this.files[parseInt(event.currentTarget.dataset.index, 10)]
    this.coverFile = this.coverFile === file ? null : file
    this.renderGallery()
  }

  galleryReordered() {
    const order = Array.from(this.thumbnailsTarget.children).map((child) => parseInt(child.dataset.id, 10))
    const reordered = order.map((index) => this.files[index]).filter(Boolean)
    if (reordered.length !== this.files.length) return

    this.files = reordered
    this.syncInputFiles()
    this.renderGallery()
  }

  renderGallery() {
    const hasFiles = this.files.length > 0
    const markedIndex = this.coverIndex()

    if (this.hasGalleryEmptyTarget) this.galleryEmptyTarget.classList.toggle("hidden", hasFiles)
    this.coverIndexInputTarget.value = markedIndex === null ? "" : markedIndex

    this.thumbnailsTarget.innerHTML = ""
    this.files.forEach((file, index) => {
      const marked = index === markedIndex
      const wrapper = document.createElement("div")
      wrapper.dataset.id = index
      wrapper.className = "relative rounded-lg overflow-hidden border border-stone-border cursor-grab"
      if (marked) wrapper.classList.add("ring-2", "ring-brand")
      wrapper.innerHTML = `
        <img src="${this.urlFor(file)}" class="w-full h-24 object-cover pointer-events-none" alt="">
        <button type="button" data-action="project-preview#selectCover" data-index="${index}"
                title="${this.coverLabel}" aria-label="${this.coverLabel}"
                aria-pressed="${marked}"
                class="absolute top-1 right-1 flex items-center justify-center w-6 h-6 rounded-full cursor-pointer ${
                  marked ? "bg-brand text-white" : "bg-black/50 text-white/90 hover:text-white"
                }">
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
    const file = this.coverFile || this.files[0] || null

    if (file) {
      this.coverTarget.src = this.urlFor(file)
      this.coverTarget.classList.remove("hidden")
      this.coverPlaceholderTarget.classList.add("hidden")
    } else {
      this.coverTarget.classList.add("hidden")
      this.coverPlaceholderTarget.classList.remove("hidden")
    }
  }

  // Index of the image explicitly marked as cover, or null when none is marked.
  coverIndex() {
    if (!this.coverFile) return null
    const index = this.files.indexOf(this.coverFile)
    return index === -1 ? null : index
  }

  syncInputFiles() {
    if (!this.hasGalleryInputTarget) return
    const dataTransfer = new DataTransfer()
    this.files.forEach((file) => dataTransfer.items.add(file))
    this.galleryInputTarget.files = dataTransfer.files
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
