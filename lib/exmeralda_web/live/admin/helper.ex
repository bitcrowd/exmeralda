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

  def datetime(datetime), do: Calendar.strftime(datetime, "%Y-%m-%d %H:%M")

  attr :state, :atom, required: true

  def ingestion_job_state(assigns) do
    ~H"""
    <span class={["badge badge-outline badge-sm", ingestion_job_state_class(@state)]}>
      {@state}
    </span>
    """
  end

  defp ingestion_job_state_class("completed"), do: "badge-success"
  defp ingestion_job_state_class("discarded"), do: "badge-error"
  defp ingestion_job_state_class(state) when state in ["scheduled", "available"], do: "badge-info"
  defp ingestion_job_state_class(_), do: "badge-warning"

  def ingestion_step(assigns) do
    assigns =
      assign_new(assigns, :step, fn ->
        find_current_step(assigns[:ingestion], assigns[:embedding_job_stats])
      end)

    ~H"""
    <p class="italic">{@step}</p>
    """
  end

  defp find_current_step(ingestion, embedding_job_stats) do
    case ExmeraldaWeb.Shared.Helper.find_current_step(ingestion) do
      :ingestion_queued ->
        gettext("Ingestion is queued.")

      :chunking_running ->
        gettext("Fetching documents and chunking...")

      :embedding_queued ->
        gettext("Embedding is queued.")

      :embedding_running ->
        gettext("Generating embeddings...")

      :chunks_embedding_running ->
        gettext("Generating embeddings for chunks... Completed workers: %{completed}/%{total}",
          completed: embedding_job_stats.completed,
          total: embedding_job_stats.total
        )

      :failed_while_chunking ->
        gettext("Failed when fetching documents or chunking")

      :failed_while_embedding ->
        gettext("Failed when embedding")

      :cancelled ->
        gettext("The job was cancelled.")

      :discarded ->
        gettext("The job was discarded.")

      :ready ->
        gettext("Done!")
    end
  end
end
