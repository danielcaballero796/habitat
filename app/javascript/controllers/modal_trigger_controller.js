import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="modal-trigger"
//
// Opens a modal that lives elsewhere in the DOM (i.e. NOT an ancestor of
// this trigger element). Stimulus resolves `data-action` targets by
// walking up the DOM from the element the action is declared on, so a
// plain `click->modal#open` only works when the trigger is INSIDE the
// modal's own `data-controller="modal"` element. Several dashboard
// triggers (e.g. the "+ Add New Device" button in the page header) are
// siblings of their modal, not descendants of it, so that direct action
// silently no-ops on click (the modal never gets Stimulus-notified; the
// browser just falls through to the link's normal full-page navigation).
//
// This controller uses a Stimulus outlet to reach across the DOM tree to
// the target modal's own `modal` controller and calls its `open()` method
// directly, without relying on DOM ancestry.
//
// Usage:
//   <%= link_to "+ Add Device", new_dashboard_device_path,
//       data: {
//         controller: "modal-trigger",
//         action: "click->modal-trigger#open",
//         "modal-trigger-modal-outlet": "#device-modal"
//       } %>
export default class extends Controller {
  static outlets = ["modal"]

  open(event) {
    event?.preventDefault()
    this.modalOutlet?.open()
  }
}
