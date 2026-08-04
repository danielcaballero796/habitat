import { Turbo } from "@hotwired/turbo-rails"

// Registers a custom Turbo Stream action: close_modal
//
// Usage from a Rails controller:
//   render turbo_stream: turbo_stream.action(:close_modal, "#device-modal")
//
// This looks up the Stimulus "modal" controller instance bound to the
// target element and calls closeViaStream() on it, so the server can close
// a modal (and reset its form) as part of a Turbo Stream response without a
// full page reload.
Turbo.StreamActions.close_modal = function () {
  this.targetElements.forEach((modal) => {
    const controller = window.Stimulus?.getControllerForElementAndIdentifier(modal, "modal")
    controller?.closeViaStream()
  })
}
