import { Controller } from "@hotwired/stimulus"

// Keeps the date-range radios and custom date fields in sync, and shows a
// generating state while the (often slow) GitHub fetch runs.
export default class extends Controller {
  static targets = ["preset", "startDate", "endDate", "customFields", "submit", "status"]

  connect() {
    // Honor restored/server-rendered/autofilled dates: select Custom instead of wiping them.
    if (this.hasFilledDates()) {
      this.selectCustomPreset()
    }
    this.syncFromPreset()
  }

  presetChanged() {
    // Only clear dates on an explicit user switch away from Custom so leftover
    // values cannot override a named preset on submit (server also treats both
    // dates as custom when present).
    this.syncFromPreset({ clearDates: true })
  }

  datesChanged() {
    if (this.hasFilledDates()) {
      this.selectCustomPreset()
    }
    this.syncFromPreset()
  }

  submitting() {
    if (this.hasStatusTarget) {
      this.statusTarget.classList.remove("hidden")
    }
    if (this.hasSubmitTarget) {
      this.submitTarget.value = "Generating…"
      // Delay disable so the browser still includes the submit control in the POST.
      requestAnimationFrame(() => {
        this.submitTarget.disabled = true
      })
    }
  }

  // --- private helpers ---

  hasFilledDates() {
    return Boolean(this.startDateTarget.value || this.endDateTarget.value)
  }

  selectedPreset() {
    const checked = this.presetTargets.find((el) => el.checked)
    return checked ? checked.value : "this_week"
  }

  selectCustomPreset() {
    const custom = this.presetTargets.find((el) => el.value === "custom")
    if (custom) custom.checked = true
  }

  syncFromPreset({ clearDates = false } = {}) {
    const isCustom = this.selectedPreset() === "custom"

    // Keep fields always interactive so users can click a date picker
    // without first selecting Custom; datesChanged will flip the radio.
    this.startDateTarget.required = isCustom
    this.endDateTarget.required = isCustom

    if (this.hasCustomFieldsTarget) {
      this.customFieldsTarget.classList.toggle("opacity-50", !isCustom)
    }

    // Match ERB selected/unselected class sets, including hover on unselected.
    this.presetTargets.forEach((radio) => {
      const label = radio.closest("label")
      if (!label) return
      const selected = radio.checked
      label.classList.toggle("border-slate-900", selected)
      label.classList.toggle("bg-slate-900", selected)
      label.classList.toggle("text-white", selected)
      label.classList.toggle("border-slate-200", !selected)
      label.classList.toggle("bg-white", !selected)
      label.classList.toggle("text-slate-700", !selected)
      label.classList.toggle("hover:bg-slate-50", !selected)
    })

    if (clearDates && !isCustom) {
      this.startDateTarget.value = ""
      this.endDateTarget.value = ""
    }
  }
}
