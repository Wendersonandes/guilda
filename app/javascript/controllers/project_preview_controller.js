import { Controller } from "@hotwired/stimulus"

// Mirrors the new-project form into the live preview (title, description, cover and gallery
// images). Images are previewed locally via object URLs until the form is submitted; the cover
// is explicitly marked among the selected gallery images (defaulting to the first).
export default class extends Controller {
  static targets = [
    "titleInput", "galleryInput", "coverIndexInput", "coverImageIdInput", "imageOrderInput", "thumbnails", "galleryEmpty",
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
    const initialCoverEl = this.hasThumbnailsTarget
      ? this.thumbnailsTarget.querySelector("[data-existing-id][data-is-cover='true']")
      : null
    this.selectedCoverType = initialCoverEl ? "existing" : null
    this.selectedCoverId = initialCoverEl ? initialCoverEl.dataset.existingId : null
    this.selectedCoverIndex = null
    this.titlePlaceholder = this.hasTitleTextTarget ? this.titleTextTarget.textContent : ""
    this.initialGalleryHtml = this.hasGalleryTarget ? this.galleryTarget.innerHTML : ""
    this.initialGalleryImages = this.hasGalleryTarget ? Array.from(this.galleryTarget.querySelectorAll("[data-existing-id]")) : []
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
    this.titleTextTarget.classList.toggle("text-zinc-400", !value)
    this.updateSubmitState()
  }

  aboutChanged() {
    const html = this.editor ? this.editor.value : ""
    const empty = this.blankHtml(html)
    this.aboutTarget.innerHTML = empty ? "" : html
    this.aboutSectionTarget.classList.toggle("hidden", empty)
    this.updateSubmitState()
  }

  // Keeps the submit button disabled until title and at least one gallery image
  // are filled in (the fields the server requires). Description is optional.
  updateSubmitState() {
    if (!this.hasSubmitButtonTarget) return

    const titleFilled = (this.titleInputTarget.value || "").trim() !== ""
    const totalImages = (this.existingImagesCountValue || 0) + this.files.length
    const galleryFilled = totalImages > 0

    this.submitButtonTarget.disabled = !(titleFilled && galleryFilled)
  }

  visibilityChanged() {
    if (!this.hasSubmitButtonTarget) return

    const input = this.element.querySelector("input[name='project[visibility]']:checked") ||
                  this.element.querySelector("input[name='project[visibility]']")
    const isDraft = input ? input.value === "draft" : false
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

    if (this.files.length > 0 && !this.selectedCoverType && (this.existingImagesCountValue || 0) === 0) {
      this.selectedCoverType = "new"
      this.selectedCoverIndex = 0
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
    const target = event.currentTarget
    if (target.dataset.existingId) {
      this.selectedCoverType = "existing"
      this.selectedCoverId = target.dataset.existingId
      this.selectedCoverIndex = null
      this.coverFile = null
    } else if (target.dataset.index !== undefined) {
      const index = parseInt(target.dataset.index, 10)
      if (isNaN(index) || index < 0 || index >= this.files.length) return

      this.selectedCoverType = "new"
      this.selectedCoverId = null
      this.selectedCoverIndex = index
      this.coverFile = this.files[index]
    }

    this.updateCoverState()
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
      if ((this.existingImagesCountValue || 0) > 0) {
        const firstExisting = this.hasThumbnailsTarget ? this.thumbnailsTarget.querySelector("[data-existing-id]") : null
        if (firstExisting) {
          this.selectedCoverType = "existing"
          this.selectedCoverId = firstExisting.dataset.existingId
          this.selectedCoverIndex = null
          this.coverFile = null
        } else {
          this.selectedCoverType = this.files.length > 0 ? "new" : null
          this.selectedCoverIndex = this.files.length > 0 ? 0 : null
          this.coverFile = this.files[0] || null
        }
      } else {
        this.selectedCoverType = this.files.length > 0 ? "new" : null
        this.selectedCoverIndex = this.files.length > 0 ? 0 : null
        this.coverFile = this.files[0] || null
      }
    } else if (this.selectedCoverType === "new" && this.coverFile) {
      this.selectedCoverIndex = this.files.indexOf(this.coverFile)
    }

    this.syncInputFiles()
    this.renderGallery()
  }

  galleryReordered() {
    if (!this.hasThumbnailsTarget) return

    const children = Array.from(this.thumbnailsTarget.children)
    const newElements = children.filter((el) => el.dataset.newImage)
    const oldIndices = newElements.map((el) => parseInt(el.dataset.newIndex, 10))
    const reorderedFiles = oldIndices.map((idx) => this.files[idx]).filter(Boolean)

    if (reorderedFiles.length === this.files.length && this.files.length > 0) {
      this.files = reorderedFiles
      this.syncInputFiles()

      newElements.forEach((el, newIdx) => {
        el.dataset.newIndex = newIdx
        el.dataset.id = `new-${newIdx}`
        el.querySelectorAll("[data-index]").forEach((btn) => {
          btn.dataset.index = newIdx
        })
        el.querySelectorAll("[data-action='project-preview#selectCover']").forEach((btn) => {
          btn.setAttribute("aria-label", `Definir imagem ${newIdx + 1} como capa do projeto`)
        })
        el.querySelectorAll("[data-action='project-preview#removeImage']").forEach((btn) => {
          btn.setAttribute("aria-label", `Remover imagem ${newIdx + 1} da galeria`)
        })
      })

      if (this.selectedCoverType === "new" && this.coverFile) {
        this.selectedCoverIndex = this.files.indexOf(this.coverFile)
      }
    }

    this.syncImageOrder()
    this.updatePreviewGallery()
    this.updateCoverState()
  }

  renderGallery() {
    const hasNewFiles = this.files.length > 0
    const totalImages = (this.existingImagesCountValue || 0) + this.files.length
    const hasAnyImages = totalImages > 0

    if (this.hasGalleryEmptyTarget) this.galleryEmptyTarget.classList.toggle("hidden", hasAnyImages)
    if (this.hasGalleryInstructionsTarget) this.galleryInstructionsTarget.classList.toggle("hidden", !hasAnyImages)

    this.updateSlotCount()

    if (this.hasThumbnailsTarget) {
      this.thumbnailsTarget.querySelectorAll("[data-new-image]").forEach((el) => el.remove())

      this.files.forEach((file, index) => {
        const isCover = this.selectedCoverType === "new" && index === this.selectedCoverIndex
        const wrapper = document.createElement("div")
        wrapper.dataset.newImage = "true"
        wrapper.dataset.id = `new-${index}`
        wrapper.dataset.newIndex = index
        wrapper.className = `relative group rounded-lg overflow-hidden border cursor-move transition-all select-none ${
          isCover ? "border-charcoal ring-2 ring-charcoal shadow-sm" : "border-stone-border hover:border-stone-400"
        }`

        const newBadge = (this.existingImagesCountValue || 0) > 0
          ? `<span class="absolute bottom-1.5 left-1.5 inline-flex items-center bg-stone-900/80 text-stone-200 text-[9px] font-medium px-1.5 py-0.5 rounded backdrop-blur-xs select-none pointer-events-none shadow-xs">
               Nova
             </span>`
          : ""

        wrapper.innerHTML = `
          <img src="${this.urlFor(file)}" class="w-full h-24 object-cover pointer-events-none select-none" alt="">
          <span data-cover-badge class="absolute top-1.5 left-1.5 inline-flex items-center gap-1 bg-charcoal text-white text-[10px] font-semibold px-2 py-0.5 rounded shadow-sm select-none ${isCover ? '' : 'hidden'}" style="${isCover ? 'display: inline-flex;' : 'display: none;'}">
            <i data-lucide="star" class="w-3 h-3 fill-amber-400 text-amber-400"></i>
            <span>Capa</span>
          </span>
          <button type="button" data-action="project-preview#selectCover" data-index="${index}" data-cover-button
                  title="Definir como capa" aria-label="Definir imagem ${index + 1} como capa do projeto"
                  class="absolute top-1.5 left-1.5 inline-flex items-center justify-center w-7 h-7 rounded-full bg-black/60 text-white/90 hover:text-white hover:bg-charcoal transition-colors cursor-pointer shadow-sm focus:outline-none focus:ring-2 focus:ring-white ${isCover ? 'hidden' : ''}" style="${isCover ? 'display: none;' : 'display: inline-flex;'}">
            <i data-lucide="star" class="w-3.5 h-3.5"></i>
          </button>
          ${newBadge}
          <button type="button" data-action="project-preview#removeImage" data-index="${index}"
                  title="Remover imagem" aria-label="Remover imagem ${index + 1} da galeria"
                  class="absolute top-1.5 right-1.5 inline-flex items-center justify-center w-7 h-7 rounded-full bg-black/60 text-white/90 hover:text-white hover:bg-red-600 transition-colors cursor-pointer shadow-sm focus:outline-none focus:ring-2 focus:ring-white">
            <i data-lucide="x" class="w-3.5 h-3.5"></i>
          </button>
        `
        this.thumbnailsTarget.appendChild(wrapper)
      })
    }

    this.updateCoverState()
    this.syncImageOrder()
    this.updatePreviewGallery()
    this.updateSubmitState()

    if (window.initLucide) window.initLucide()
  }

  updateCoverState() {
    if (!this.hasThumbnailsTarget) return

    if (this.hasCoverIndexInputTarget) {
      this.coverIndexInputTarget.value = this.selectedCoverType === "new" ? (this.selectedCoverIndex ?? "") : ""
    }
    if (this.hasCoverImageIdInputTarget) {
      this.coverImageIdInputTarget.value = this.selectedCoverType === "existing" ? (this.selectedCoverId ?? "") : ""
    }

    this.thumbnailsTarget.querySelectorAll("[data-existing-id]").forEach((el) => {
      const isThisCover = this.selectedCoverType === "existing" && String(el.dataset.existingId) === String(this.selectedCoverId)
      const badge = el.querySelector("[data-cover-badge]")
      const btn = el.querySelector("[data-cover-button]")

      el.classList.toggle("border-charcoal", isThisCover)
      el.classList.toggle("ring-2", isThisCover)
      el.classList.toggle("ring-charcoal", isThisCover)
      el.classList.toggle("shadow-sm", isThisCover)
      el.classList.toggle("border-stone-border", !isThisCover)
      el.classList.toggle("hover:border-stone-400", !isThisCover)

      if (badge) {
        badge.classList.toggle("hidden", !isThisCover)
        badge.style.display = isThisCover ? "inline-flex" : "none"
      }
      if (btn) {
        btn.classList.toggle("hidden", isThisCover)
        btn.style.display = isThisCover ? "none" : "inline-flex"
      }
    })

    this.thumbnailsTarget.querySelectorAll("[data-new-image]").forEach((el) => {
      const idx = parseInt(el.dataset.newIndex, 10)
      const isThisCover = this.selectedCoverType === "new" && idx === this.selectedCoverIndex
      const badge = el.querySelector("[data-cover-badge]")
      const btn = el.querySelector("[data-cover-button]")

      el.classList.toggle("border-charcoal", isThisCover)
      el.classList.toggle("ring-2", isThisCover)
      el.classList.toggle("ring-charcoal", isThisCover)
      el.classList.toggle("shadow-sm", isThisCover)
      el.classList.toggle("border-stone-border", !isThisCover)
      el.classList.toggle("hover:border-stone-400", !isThisCover)

      if (badge) {
        badge.classList.toggle("hidden", !isThisCover)
        badge.style.display = isThisCover ? "inline-flex" : "none"
      }
      if (btn) {
        btn.classList.toggle("hidden", isThisCover)
        btn.style.display = isThisCover ? "none" : "inline-flex"
      }
    })

    this.updatePreviewCover()
    if (window.initLucide) window.initLucide()
  }

  syncImageOrder() {
    if (!this.hasImageOrderInputTarget || !this.hasThumbnailsTarget) return

    const children = Array.from(this.thumbnailsTarget.children)
    const order = children.map((el) => {
      if (el.dataset.existingId) return `existing:${el.dataset.existingId}`
      if (el.dataset.newImage) return `new:${el.dataset.newIndex}`
      return null
    }).filter(Boolean)

    this.imageOrderInputTarget.value = JSON.stringify(order)
  }

  updatePreviewGallery() {
    if (!this.hasGalleryTarget) return

    const totalImages = (this.existingImagesCountValue || 0) + this.files.length
    if (this.hasGallerySectionTarget) {
      this.gallerySectionTarget.classList.toggle("hidden", totalImages === 0)
    }

    if (!this.hasThumbnailsTarget) return

    const children = Array.from(this.thumbnailsTarget.children)
    if (children.length === 0) {
      this.galleryTarget.innerHTML = ""
      return
    }

    const existingMap = new Map()
    if (this.initialGalleryImages) {
      this.initialGalleryImages.forEach((img) => {
        existingMap.set(String(img.dataset.existingId), img)
      })
    }

    this.galleryTarget.innerHTML = ""
    children.forEach((child) => {
      if (child.dataset.existingId) {
        const existingImg = existingMap.get(String(child.dataset.existingId))
        if (existingImg) {
          this.galleryTarget.appendChild(existingImg.cloneNode(true))
        }
      } else if (child.dataset.newImage) {
        const idx = parseInt(child.dataset.newIndex, 10)
        const file = this.files[idx]
        if (file) {
          const img = document.createElement("img")
          img.src = this.urlFor(file)
          img.className = "w-full aspect-[4/3] object-cover rounded-lg border border-stone-border"
          img.alt = ""
          this.galleryTarget.appendChild(img)
        }
      }
    })
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

    if (this.selectedCoverType === "new" && this.coverFile) {
      this.coverContainerTarget.innerHTML = `<img src="${this.urlFor(this.coverFile)}" alt="Capa do projeto" class="w-full h-full object-cover">`
      this.coverContainerTarget.classList.remove("hidden")
      this.coverPlaceholderTarget.classList.add("hidden")
    } else if (this.selectedCoverType === "existing" && this.selectedCoverId && this.hasThumbnailsTarget) {
      const existingImg = this.thumbnailsTarget.querySelector(`[data-existing-id='${this.selectedCoverId}'] img`)
      if (existingImg) {
        this.coverContainerTarget.innerHTML = `<img src="${existingImg.src}" alt="Capa do projeto" class="w-full h-full object-cover">`
        this.coverContainerTarget.classList.remove("hidden")
        this.coverPlaceholderTarget.classList.add("hidden")
      }
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
    if (!this.coverFile) {
      return (this.existingImagesCountValue || 0) === 0 ? 0 : null
    }
    const index = this.files.indexOf(this.coverFile)
    return index === -1 ? ((this.existingImagesCountValue || 0) === 0 ? 0 : null) : index
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
