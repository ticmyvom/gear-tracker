import { Controller } from "@hotwired/stimulus"

// Scrolls its element to the top of the window, like a link to #id would.
// After a form is saved, Turbo drops the #id from the address it's sent to,
// so the server marks the element instead. Turbo scrolls to the top once it
// has shown the page, so this scrolls again after that.
export default class extends Controller {
  connect() {
    this.scroll()
    document.addEventListener("turbo:load", () => this.scroll(), { once: true })
  }

  scroll() {
    this.element.scrollIntoView()
    // Puts the #id in the address too, so reloading stays here.
    history.replaceState(history.state, "", `#${this.element.id}`)
  }
}
