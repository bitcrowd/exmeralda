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

  attr :state, :atom, required: true

  def ingestion_state(assigns) do
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

  defp find_current_step(%{state: :queued, job: %{state: state}}, _)
       when state in ["scheduled", "available"],
       do: gettext("Ingestion is queued.")

  defp find_current_step(%{state: :queued, job: %{state: state}}, _)
       when state in ["executing", "retryable"],
       do: gettext("Fetching documents and chunking...")

  defp find_current_step(%{state: :embedding, job: %{state: state}}, _)
       when state in ["scheduled", "available"],
       do: gettext("Embedding is queued.")

  defp find_current_step(%{state: :embedding, job: %{state: state}}, _)
       when state in ["executing", "retryable"],
       do: gettext("Generating embeddings...")

  # The parent GenerateEmbeddingsWorker has run and all the chunk children
  # worker are now running
  defp find_current_step(%{state: :embedding, job: %{state: "completed"}}, %{
         total: total,
         completed: completed
       }) do
    gettext("Generating embeddings for chunks... Completed workers: %{completed}/%{total}",
      completed: completed,
      total: total
    )
  end

  defp find_current_step(
         %{
           state: :failed,
           job: %{worker: "Exmeralda.Topics.IngestLibraryWorker"}
         },
         _
       ),
       do: gettext("Failed when fetching documents or chunking")

  defp find_current_step(
         %{
           state: :failed,
           job: %{worker: "Exmeralda.Topics.GenerateEmbeddingsWorker"}
         },
         _
       ),
       do: gettext("Failed when embedding")

  defp find_current_step(%{state: :ready}, _), do: gettext("Done!")
  defp find_current_step(%{job: %{state: "cancelled"}}, _), do: gettext("The job was cancelled.")
  defp find_current_step(%{job: %{state: "discarded"}}, _), do: gettext("The job was discarded.")
  defp find_current_step(_, _), do: gettext("Unknown")
end
