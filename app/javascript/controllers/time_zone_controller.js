import { Controller } from "@hotwired/stimulus"

// Fills an empty time zone field with the browser's, like "America/Los_Angeles",
// so new accounts don't have to pick one. A zone already chosen is kept.
export default class extends Controller {
  connect() {
    if (this.element.value) return

    const zone = Intl.DateTimeFormat().resolvedOptions().timeZone
    // For a select, only a zone it lists; otherwise it would stay blank anyway.
    if (this.element.tagName !== "SELECT" || [...this.element.options].some(option => option.value === zone)) {
      this.element.value = zone
    }
  }
}
