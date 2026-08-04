import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="confirm-delete"
//
// Wraps a set of delete-trigger links/buttons and the single shared
// delete-confirmation modal they open (see
// app/views/dashboard/devices/_delete_confirmation.html.erb and the
// device_attributes equivalent). A trigger sets data-delete-url and
// data-delete-name on itself; this controller copies delete-url onto the
// confirmation form's action, fills in delete-name, then opens the modal.
//
// Opening goes through the modal's own Stimulus outlet (rather than
// toggling the "open" class directly) so the confirmation dialog gets the
// same focus-trap / return-focus accessibility behavior as every other
// modal (see modal_controller.js#open).
export default class extends Controller {
  static targets = ["modal", "form", "name"]
  static outlets = ["modal"]

  show(event) {
    event.preventDefault()
    const { deleteUrl, deleteName } = event.currentTarget.dataset

    if (this.hasFormTarget && deleteUrl) this.formTarget.action = deleteUrl
    if (this.hasNameTarget && deleteName) this.nameTarget.textContent = deleteName

    if (this.hasModalOutlet) {
      this.modalOutlet.open(event)
    } else {
      this.modalTarget.classList.add("open")
    }
  }
}
