import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="modal"
//
// Manages the open/close lifecycle of a single modal overlay (see
// app/views/shared/_modal.html.erb). Shared by every create/edit/delete
// modal in the dashboard.
export default class extends Controller {
  connect() {
    this.boundHandleKeydown = this.handleKeydown.bind(this)
  }

  disconnect() {
    document.removeEventListener("keydown", this.boundHandleKeydown)
  }

  // Opens the modal, traps focus inside it, and remembers which element
  // triggered the open so focus can be restored to it on close.
  open(event) {
    event?.preventDefault()
    this.triggerElement = event?.currentTarget || document.activeElement
    this.element.classList.add("open")
    this.focusFirstElement()
    document.addEventListener("keydown", this.boundHandleKeydown)
  }

  // Closes the modal, resets its form, releases the focus trap, and
  // returns focus to whatever element opened the modal.
  close(event) {
    event?.preventDefault()
    this.element.classList.remove("open")
    this.resetForm()
    document.removeEventListener("keydown", this.boundHandleKeydown)
    this.returnFocus()
  }

  // Closes the modal when the user clicks the backdrop (outside the modal
  // content), but not when they click inside the modal content itself.
  closeOnBackdrop(event) {
    if (event.target.classList.contains("modal-backdrop")) {
      this.close()
    }
  }

  // Closes the modal from a Turbo Stream custom action (see
  // app/javascript/controllers/turbo_stream_actions.js). No `event` is
  // available here since it's not triggered by a DOM event.
  closeViaStream() {
    this.element.classList.remove("open")
    this.resetForm()
    document.removeEventListener("keydown", this.boundHandleKeydown)
    this.returnFocus()
  }

  // Moves focus back to the element that opened the modal (e.g. the
  // "+ Add New Device" link or a row's Delete button), matching standard
  // accessible modal behavior so keyboard/screen-reader users aren't left
  // stranded with focus on a now-hidden element.
  returnFocus() {
    this.triggerElement?.focus?.()
    this.triggerElement = null
  }

  // Focuses the first real form field inside the modal (skipping the "x"
  // close button, which is first in DOM order but not the useful place to
  // land focus), falling back to the close button if the modal has no
  // fields (e.g. a confirmation dialog).
  focusFirstElement() {
    const focusable = this.focusableElements()
    const closeButton = this.element.querySelector(".modal-close")
    const firstField = focusable.find((element) => element !== closeButton)
    ;(firstField || focusable[0])?.focus()
  }

  // Returns every focusable element currently visible inside the modal, in
  // DOM order. Used both to pick the initial focus target and to compute
  // the Tab-cycle boundaries in handleKeydown.
  focusableElements() {
    const elements = this.element.querySelectorAll(
      'input:not([disabled]), select:not([disabled]), textarea:not([disabled]), button:not([disabled]), a[href]'
    )
    return Array.from(elements).filter((element) => element.offsetParent !== null)
  }

  // Traps Tab/Shift+Tab focus within the modal's own focusable elements
  // while it's open (so keyboard focus never escapes to the page behind
  // it), and closes the modal on Escape.
  handleKeydown(event) {
    if (!this.element.classList.contains("open")) return

    if (event.key === "Escape") {
      this.close()
      return
    }

    if (event.key !== "Tab") return

    const focusable = this.focusableElements()
    if (focusable.length === 0) return

    const first = focusable[0]
    const last = focusable[focusable.length - 1]

    if (event.shiftKey && document.activeElement === first) {
      event.preventDefault()
      last.focus()
    } else if (!event.shiftKey && document.activeElement === last) {
      event.preventDefault()
      first.focus()
    }
  }

  // Resets the form fields and clears any leftover
  // ActionView field_with_errors wrapper artifacts from a previous
  // failed submission.
  resetForm() {
    const form = this.element.querySelector("form")
    if (!form) return

    form.reset()

    form.querySelectorAll(".field_with_errors").forEach((field) => {
      field.classList.remove("field_with_errors")
    })
  }
}
