import { Controller } from "@hotwired/stimulus"

// Mirrors the new-project form into the live preview (title, description, cover and gallery
// images). Images are previewed locally via object URLs until the form is submitted; the cover
// is explicitly marked among the selected gallery images (defaulting to the first).
export default class extends Controller {
  static targets = [
    "titleInput", "galleryInput", "coverIndexInput", "thumbnails", "galleryEmpty",
    "galleryInstructions", "slotCount", "submitButton", "dropzone", "galleryError",
    "titleText", "about", "aboutSection", "coverContainer", "coverPlaceholder",
    "gallery", "gallerySection"
  ]

  static values = {
    maxImages: { type: Number, default: 10 },
    existingImagesCount: { type: Number, default: 0 }
  }

  connect() {
    this.urls = new Map()
    this.files = []
    this.coverFile = null
    this.titlePlaceholder = this.hasTitleTextTarget ? this.titleTextTarget.textContent : ""
    this.initialGalleryHtml = this.hasGalleryTarget ? this.galleryTarget.innerHTML : ""
    this.initialCoverHtml = this.hasCoverContainerTarget ? this.coverContainerTarget.innerHTML : ""

    this.editor = this.element.querySelector("lexxy-editor")
    if (this.editor) {
      this.onEditorChange = () => this.aboutChanged()
      this.editor.addEventListener("lexxy:change", this.onEditorChange)
    }

    this.form = this.element.querySelector("form")
    if (this.form) {
      this.onSubmit = (event) => this.validateSubmission(event)
      this.form.addEventListener("submit", this.onSubmit)
    }

    this.titleChanged()
    this.aboutChanged()
    this.visibilityChanged()
    this.renderGallery()
  }

  disconnect() {
    if (this.editor && this.onEditorChange) this.editor.removeEventListener("lexxy:change", this.onEditorChange)
    if (this.form && this.onSubmit) this.form.removeEventListener("submit", this.onSubmit)
    this.revokeUrls()
  }

  titleChanged() {
    const value = (this.titleInputTarget.value || "").trim()
    this.titleTextTarget.textContent = value || this.titlePlaceholder
    this.titleTextTarget.classList.toggle("text-zinc-300", !value)
    this.updateSubmitState()
  }

  aboutChanged() {
    const html = this.editor ? this.editor.value : ""
    const empty = this.blankHtml(html)
    this.aboutTarget.innerHTML = empty ? "" : html
    this.aboutSectionTarget.classList.toggle("hidden", empty)
    this.updateSubmitState()
  }

  // Keeps the submit button disabled until title, description and at least one gallery image
  // are filled in (the same fields the server requires).
  updateSubmitState() {
    if (!this.hasSubmitButtonTarget) return

    const titleFilled = (this.titleInputTarget.value || "").trim() !== ""
    const aboutFilled = this.editor ? !this.blankHtml(this.editor.value) : false
    const totalImages = (this.existingImagesCountValue || 0) + this.files.length
    const galleryFilled = totalImages > 0

    this.submitButtonTarget.disabled = !(titleFilled && aboutFilled && galleryFilled)
  }

  visibilityChanged() {
    if (!this.hasSubmitButtonTarget) return

    const selectedRadio = this.element.querySelector("input[name='project[visibility]']:checked")
    const isDraft = selectedRadio && selectedRadio.value === "draft"
    const publishText = this.submitButtonTarget.dataset.publishText || "Publicar projeto"
    const draftText = this.submitButtonTarget.dataset.draftText || "Salvar como rascunho"

    this.submitButtonTarget.value = isDraft ? draftText : publishText
  }

  galleryChanged() {
    const incoming = Array.from(this.galleryInputTarget.files || [])
    if (!incoming.length) return

    const max = this.maxImagesValue || 10
    const availableSlots = Math.max(0, max - (this.existingImagesCountValue || 0))
    const existingKeys = new Set(this.files.map((f) => `${f.name}-${f.size}-${f.lastModified}`))

    for (const file of incoming) {
      const key = `${file.name}-${file.size}-${file.lastModified}`
      if (!existingKeys.has(key) && this.files.length < availableSlots) {
        existingKeys.add(key)
        this.files.push(file)
      }
    }

    if (this.files.length > 0 && !this.coverFile && (this.existingImagesCountValue || 0) === 0) {
      this.coverFile = this.files[0]
    }

    if (this.files.length > 0 || (this.existingImagesCountValue || 0) > 0) {
      this.clearGalleryError()
    }

    this.syncInputFiles()
    this.renderGallery()
  }

  selectCover(event) {
    event.stopPropagation()
    const index = parseInt(event.currentTarget.dataset.index, 10)
    if (isNaN(index) || index < 0 || index >= this.files.length) return

    this.coverFile = this.files[index]
    this.renderGallery()
  }

  removeImage(event) {
    event.stopPropagation()
    const index = parseInt(event.currentTarget.dataset.index, 10)
    if (isNaN(index) || index < 0 || index >= this.files.length) return

    const removed = this.files.splice(index, 1)[0]
    if (removed && this.urls.has(removed)) {
      URL.revokeObjectURL(this.urls.get(removed))
      this.urls.delete(removed)
    }

    if (this.coverFile === removed) {
      this.coverFile = this.files[0] || null
    }

    this.syncInputFiles()
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
    const hasNewFiles = this.files.length > 0
    const totalImages = (this.existingImagesCountValue || 0) + this.files.length
    const hasAnyImages = totalImages > 0
    const markedIndex = this.coverIndex()

    if (this.hasGalleryEmptyTarget) this.galleryEmptyTarget.classList.toggle("hidden", hasAnyImages)
    if (this.hasGalleryInstructionsTarget) this.galleryInstructionsTarget.classList.toggle("hidden", !hasNewFiles)
    if (this.hasCoverIndexInputTarget) {
      this.coverIndexInputTarget.value = markedIndex === null ? "" : markedIndex
    }

    this.updateSlotCount()

    if (this.hasThumbnailsTarget) {
      this.thumbnailsTarget.innerHTML = ""
      this.files.forEach((file, index) => {
        const isCover = index === markedIndex
        const wrapper = document.createElement("div")
        wrapper.dataset.id = index
        wrapper.className = `relative rounded-lg overflow-hidden border cursor-move transition-all ${
          isCover ? "border-charcoal ring-2 ring-charcoal shadow-sm" : "border-stone-border hover:border-stone-400"
        }`

        const coverElement = isCover
          ? `<span class="absolute top-1.5 left-1.5 inline-flex items-center gap-1 bg-charcoal text-white text-[10px] font-semibold px-2 py-0.5 rounded shadow-sm select-none">
               <i data-lucide="star" class="w-3 h-3 fill-amber-400 text-amber-400"></i>
               <span>Capa</span>
             </span>`
          : `<button type="button" data-action="project-preview#selectCover" data-index="${index}"
                     title="Definir como capa" aria-label="Definir imagem ${index + 1} como capa do projeto"
                     class="absolute top-1.5 left-1.5 inline-flex items-center justify-center w-7 h-7 rounded-full bg-black/60 text-white/90 hover:text-white hover:bg-charcoal transition-colors cursor-pointer shadow-sm focus:outline-none focus:ring-2 focus:ring-white">
               <i data-lucide="star" class="w-3.5 h-3.5"></i>
             </button>`

        wrapper.innerHTML = `
          <img src="${this.urlFor(file)}" class="w-full h-24 object-cover pointer-events-none select-none" alt="">
          ${coverElement}
          <button type="button" data-action="project-preview#removeImage" data-index="${index}"
                  title="Remover imagem" aria-label="Remover imagem ${index + 1} da galeria"
                  class="absolute top-1.5 right-1.5 inline-flex items-center justify-center w-7 h-7 rounded-full bg-black/60 text-white/90 hover:text-white hover:bg-red-600 transition-colors cursor-pointer shadow-sm focus:outline-none focus:ring-2 focus:ring-white">
            <i data-lucide="x" class="w-3.5 h-3.5"></i>
          </button>
        `
        this.thumbnailsTarget.appendChild(wrapper)
      })
    }

    if (window.initLucide) window.initLucide()

    if (this.hasGalleryTarget) {
      if (hasNewFiles) {
        this.galleryTarget.innerHTML = this.initialGalleryHtml || ""
        this.files.forEach((file) => {
          const img = document.createElement("img")
          img.src = this.urlFor(file)
          img.className = "w-full aspect-[4/3] object-cover rounded-lg border border-stone-border"
          img.alt = ""
          this.galleryTarget.appendChild(img)
        })
      } else if (this.initialGalleryHtml && this.initialGalleryHtml.trim() !== "") {
        this.galleryTarget.innerHTML = this.initialGalleryHtml
      } else {
        this.galleryTarget.innerHTML = ""
      }
    }
    if (this.hasGallerySectionTarget) {
      this.gallerySectionTarget.classList.toggle("hidden", !hasAnyImages)
    }

    this.updatePreviewCover()
    this.updateSubmitState()
  }

  updateSlotCount() {
    if (!this.hasSlotCountTarget) return

    const max = this.maxImagesValue || 10
    const existing = this.existingImagesCountValue || 0
    const totalCurrent = existing + this.files.length

    if (totalCurrent === 0) {
      this.slotCountTarget.textContent = `Até ${max} imagens`
      this.slotCountTarget.classList.remove("text-amber-600")
    } else {
      const remaining = Math.max(0, max - totalCurrent)
      if (remaining === 0) {
        this.slotCountTarget.textContent = `Limite atingido (${max}/${max})`
        this.slotCountTarget.classList.add("text-amber-600")
      } else {
        const word = remaining === 1 ? "vaga restante" : "vagas restantes"
        this.slotCountTarget.textContent = `${totalCurrent}/${max} · ${remaining} ${word}`
        this.slotCountTarget.classList.remove("text-amber-600")
      }
    }
  }

  updatePreviewCover() {
    if (!this.hasCoverContainerTarget || !this.hasCoverPlaceholderTarget) return

    const file = this.coverFile || (this.existingImagesCountValue === 0 ? this.files[0] : null)

    if (file) {
      this.coverContainerTarget.innerHTML = `<img src="${this.urlFor(file)}" alt="Capa do projeto" class="w-full max-h-[500px] object-cover">`
      this.coverContainerTarget.classList.remove("hidden")
      this.coverPlaceholderTarget.classList.add("hidden")
    } else if (this.initialCoverHtml && this.initialCoverHtml.trim() !== "") {
      this.coverContainerTarget.innerHTML = this.initialCoverHtml
      this.coverContainerTarget.classList.remove("hidden")
      this.coverPlaceholderTarget.classList.add("hidden")
    } else {
      this.coverContainerTarget.innerHTML = ""
      this.coverContainerTarget.classList.add("hidden")
      this.coverPlaceholderTarget.classList.remove("hidden")
    }
  }

  coverIndex() {
    if (!this.files.length) return null
    if (!this.coverFile) return 0
    const index = this.files.indexOf(this.coverFile)
    return index === -1 ? 0 : index
  }

  syncInputFiles() {
    if (!this.hasGalleryInputTarget) return
    const dataTransfer = new DataTransfer()
    this.files.forEach((file) => dataTransfer.items.add(file))
    this.galleryInputTarget.files = dataTransfer.files
  }

  urlFor(file) {
    if (!this.urls.has(file)) this.urls.set(file, URL.createObjectURL(file))
    return this.urls.get(file)
  }

  revokeUrls() {
    this.urls.forEach((url) => URL.revokeObjectURL(url))
    this.urls.clear()
  }

  validateSubmission(event) {
    const totalImages = (this.existingImagesCountValue || 0) + this.files.length
    if (totalImages === 0) {
      event.preventDefault()
      event.stopPropagation()
      this.showGalleryError()
    }
  }

  showGalleryError() {
    if (this.hasDropzoneTarget) {
      this.dropzoneTarget.classList.add("border-red-500", "bg-red-50/50", "ring-2", "ring-red-200")
      this.dropzoneTarget.scrollIntoView({ behavior: "smooth", block: "center" })
    }
    if (this.hasGalleryErrorTarget) {
      this.galleryErrorTarget.classList.remove("hidden")
    }
    if (window.initLucide) window.initLucide()
  }

  clearGalleryError() {
    if (this.hasDropzoneTarget) {
      this.dropzoneTarget.classList.remove("border-red-500", "bg-red-50/50", "ring-2", "ring-red-200")
    }
    if (this.hasGalleryErrorTarget) {
      this.galleryErrorTarget.classList.add("hidden")
    }
  }

  blankHtml(html) {
    const element = document.createElement("div")
    element.innerHTML = html || ""
    return element.textContent.trim() === ""
  }
}
