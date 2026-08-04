import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="modal"
//
// Manages the open/close lifecycle of a single modal overlay (see
// app/views/shared/_modal.html.erb). Shared by every create/edit/delete
// modal in the dashboard.
export default class extends Controller {
  // Opens the modal and focuses the first input in its form.
  open(event) {
    event?.preventDefault()
    this.element.classList.add("open")
    this.element.querySelector("input:first-of-type")?.focus()
  }

  // Closes the modal and resets its form.
  close(event) {
    event?.preventDefault()
    this.element.classList.remove("open")
    this.resetForm()
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
