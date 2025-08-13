defmodule ExmeraldaWeb.Shared.Helper do
  use ExmeraldaWeb, :component

  attr :state, :atom, required: true

  def ingestion_state_badge(assigns) do
    ~H"""
    <span class={["badge", ingestion_state_class(@state)]}>
      {@state}
    </span>
    """
  end

  defp ingestion_state_class(:ready), do: "badge-success"
  defp ingestion_state_class(:failed), do: "badge-error"
  defp ingestion_state_class(:queued), do: "badge-info"
  defp ingestion_state_class(_), do: "badge-warning"
end
