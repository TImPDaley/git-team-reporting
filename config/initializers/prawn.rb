# frozen_string_literal: true

# Built-in AFM fonts are Windows-1252; PdfRenderer sanitizes text. Silence the
# library warning so generation logs stay clean in production/test.
if defined?(Prawn::Fonts::AFM)
  Prawn::Fonts::AFM.hide_m17n_warning = true
end
