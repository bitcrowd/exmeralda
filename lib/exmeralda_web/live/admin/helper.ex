defmodule ExmeraldaWeb.Admin.Helper do
  use ExmeraldaWeb, :component

  attr :icon_name, :string, required: true
  attr :title, :string, required: true
  attr :value, :integer, required: true
  attr :total, :integer
  attr :text_variant, :string, default: "text-primary"
  attr :value_variant, :string, default: "text-primary"

  def stat(assigns) do
    ~H"""
    <div class="stat">
      <div class={"stat-figure #{@text_variant}"}>
        <.icon name={@icon_name} />
      </div>
      <div class="stat-title">{@title}</div>
      <div class={"stat-value #{@value_variant}"}>
        {@value}
        <div :if={assigns[:total]} class="stat-desc">
          {"#{percent(assigns)}%"}
        </div>
      </div>
    </div>
    """
  end

  defp percent(%{total: 0}), do: "0"

  defp percent(%{total: total, value: value}), do: div(value * 100, total)

  def library_title(library), do: "#{library.name} #{library.version}"
end
