defmodule ExmeraldaWeb.Shared.Helper do
  use ExmeraldaWeb, :component

  attr :state, :atom, required: true

  def ingestion_state_badge(assigns) do
    ~H"""
    <span class={["badge badge-soft", ingestion_state_class(@state)]}>
      {@state}
    </span>
    """
  end

  defp ingestion_state_class(:ready), do: "badge-success"
  defp ingestion_state_class(:failed), do: "badge-error"
  defp ingestion_state_class(:queued), do: "badge-info"
  defp ingestion_state_class(_), do: "badge-warning"

  # credo:disable-for-lines:20 Credo.Check.Refactor.CyclomaticComplexity
  def find_current_step(%{state: :queued, job: %{state: state}})
      when state in ["scheduled", "available"],
      do: :ingestion_queued

  def find_current_step(%{state: :queued, job: %{state: state}})
      when state in ["executing", "retryable"],
      do: :chunking_running

  def find_current_step(%{state: :embedding, job: %{state: state}})
      when state in ["scheduled", "available"],
      do: :embedding_queued

  def find_current_step(%{state: :embedding, job: %{state: state}})
      when state in ["executing", "retryable"],
      do: :embedding_running

  # The parent GenerateEmbeddingsWorker has run and all the chunk children
  # worker are now running
  def find_current_step(%{state: :embedding, job: %{state: "completed"}}),
    do: :chunks_embedding_running

  def find_current_step(%{
        state: :failed,
        job: %{worker: "Exmeralda.Topics.IngestLibraryWorker"}
      }),
      do: :failed_while_chunking

  def find_current_step(%{
        state: :failed,
        job: %{worker: "Exmeralda.Topics.GenerateEmbeddingsWorker"}
      }),
      do: :failed_while_embedding

  def find_current_step(%{state: :ready}), do: :ready
  def find_current_step(%{job: %{state: "cancelled"}}), do: :cancelled
  def find_current_step(%{job: %{state: "discarded"}}), do: :discarded
  def find_current_step(_), do: :unknown

  attr :library, :map, required: true
  attr :badge_class, :string, default: ""
  attr :class, :string, default: ""

  def library(assigns) do
    ~H"""
    {@library.name}
    <span class={["badge badge-primary", @badge_class]}>{@library.version}</span>
    """
  end
end
