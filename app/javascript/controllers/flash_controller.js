import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="flash"
//
// Auto-dismisses a flash/alert message a few seconds after it appears,
// whether it was rendered on page load or inserted via a Turbo Stream
// update. Not covered by request specs (no JS driver in this repo) —
// verify manually in the browser.
export default class extends Controller {
  static values = { delay: { type: Number, default: 3000 } }

  connect() {
    this.timeout = setTimeout(() => this.dismiss(), this.delayValue)
  }

  disconnect() {
    clearTimeout(this.timeout)
  }

  dismiss() {
    this.element.remove()
  }
}
