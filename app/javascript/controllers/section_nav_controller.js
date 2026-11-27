import { Controller } from "@hotwired/stimulus"

// Jumps to a section when its key is pressed, like F for the fuel log. Each
// link names its key in aria-keyshortcuts, which also tells screen readers.
// Keys are ignored while typing in a field, or with Ctrl, Alt or Cmd, so
// shortcuts like Ctrl+F still work.
export default class extends Controller {
  jump(event) {
    if (event.defaultPrevented || event.ctrlKey || event.altKey || event.metaKey) return
    if (event.target.closest("input, textarea, select, [contenteditable]")) return

    const key = event.key.toLowerCase()
    const link = [...this.element.querySelectorAll("[aria-keyshortcuts]")].find(it => it.getAttribute("aria-keyshortcuts") === key)
    if (link) {
      event.preventDefault()
      link.click()
    }
  }
}
