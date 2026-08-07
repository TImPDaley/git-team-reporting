# frozen_string_literal: true

module ApplicationHelper
  def nav_link_to(name, path, **options)
    active = current_page?(path) || (path != root_path && request.path.start_with?(path))
    classes = [
      "inline-flex items-center rounded-lg px-3 py-2 text-sm font-medium transition",
      (active ? "bg-slate-900 text-white shadow-sm" : "text-slate-600 hover:bg-slate-100 hover:text-slate-900")
    ].join(" ")
    link_to name, path, class: classes, **options
  end

  def flash_class(type)
    case type.to_s
    when "notice" then "bg-emerald-50 text-emerald-900 border-emerald-200"
    when "alert" then "bg-rose-50 text-rose-900 border-rose-200"
    else "bg-slate-50 text-slate-900 border-slate-200"
    end
  end

  def metric_cell(value)
    value.nil? ? "—" : value
  end

  def button_classes(variant = :primary)
    base = "btn"
    case variant.to_sym
    when :secondary then "#{base} btn-secondary"
    when :danger then "#{base} btn-danger"
    else "#{base} btn-primary"
    end
  end
end
