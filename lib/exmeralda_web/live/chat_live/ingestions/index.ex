defmodule ExmeraldaWeb.ChatLive.Ingestions.Index do
  use ExmeraldaWeb, :live_component
  import ExmeraldaWeb.Shared.Helper
  alias Exmeralda.Topics

  @impl true
  def update(%{event: :ingestion_created, ingestion: ingestion}, socket) do
    ongoing_ingestions = socket.assigns.ongoing_ingestions
    {:ok, assign(socket, :ongoing_ingestions, [ingestion | ongoing_ingestions])}
  end

  def update(%{event: :ingestion_state_updated, ingestion: ingestion}, socket) do
    %{ready_ingestions: ready_ingestions, ongoing_ingestions: ongoing_ingestions} = socket.assigns

    socket =
      if ingestion.state in [:ready, :failed] do
        socket
        |> assign(:ongoing_ingestions, Enum.reject(ongoing_ingestions, &(&1.id == ingestion.id)))
        |> assign(:ready_ingestions, [ingestion | ready_ingestions])
      else
        assign(
          socket,
          :ongoing_ingestions,
          Enum.map(
            ongoing_ingestions,
            &if(&1.id == ingestion.id,
              do: ingestion,
              else: &1
            )
          )
        )
      end

    {:ok, socket}
  end

  def update(_params, socket) do
    socket =
      socket
      |> assign(:page_title, "Latest Library Updates")
      |> assign(
        :ongoing_ingestions,
        Topics.last_ingestions([:queued, :preprocessing, :chunking, :embedding])
      )
      |> assign(:ready_ingestions, Topics.last_ingestions([:ready, :failed]))

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <article class="mt-4 mx-8">
      <div class="grid grid-cols-1 sm:grid-cols-2 justify-between">
        <h2 class="text-xl pb-4 font-bold">
          {gettext("Latest Library Updates")}
        </h2>
      </div>

      <div class="flex">
        <div class="w-2/3">
          <h3 class="text-lg mb-2">
            <.icon name="hero-cube-transparent-mini" />
            {gettext("Ongoing...")}
          </h3>
          <.table items={@ongoing_ingestions}>
            <:col :let={ingestion} label="Name">
              {ingestion.library.name}
            </:col>
            <:col :let={ingestion} label="Version">
              {ingestion.library.version}
            </:col>
            <:col :let={ingestion} label="State">
              <.ingestion_state_badge state={ingestion.state} />
            </:col>
            <:col :let={ingestion} label="Job state" label_class="sr-only">
              <.ingestion_job_state ingestion={ingestion} />
            </:col>
          </.table>
        </div>

        <div class="w-1/3">
          <h3 class="text-lg mb-2 pl-2">
            <.icon name="hero-cube-mini" />
            {gettext("Last processed libraries")}
          </h3>
          <ul class="menu px-0 w-full">
            <li :for={ingestion <- @ready_ingestions}>
              <%= if ingestion.state == :failed do %>
                <div
                  class="flex place-content-between tooltip text-gray-300"
                  data-tip={gettext("We're investigating")}
                >
                  <.library library={ingestion.library} badge_class="badge-error" />
                </div>
              <% else %>
                <.link patch={~p"/chat/start?selected_library=#{ingestion.library.id}"}>
                  <.library library={ingestion.library} />
                </.link>
              <% end %>
            </li>
          </ul>
        </div>
      </div>
    </article>
    """
  end

  defp ingestion_job_state(assigns) do
    assigns = assign_new(assigns, :current_step, fn -> find_current_step(assigns[:ingestion]) end)

    ~H"""
    <div
      :if={
        @current_step in [
          :ingestion_queued,
          :chunking_running,
          :embedding_queued,
          :embedding_running,
          :chunks_embedding_running
        ]
      }
      class="flex gap-2 items-center"
    >
      <.icon name="hero-arrow-path" class="ml-1 h-3 w-3 animate-spin" />
      <p class="italic text-xs text-gray-500">{current_step_message(@current_step)}</p>
    </div>
    """
  end

  defp current_step_message(:ingestion_queued), do: gettext("The library will soon be processed")

  # Only shown with a page reload as this doesn't match any state update.
  defp current_step_message(:chunking_running),
    do: gettext("Fetching library documents and dependencies...")

  defp current_step_message(_step), do: gettext("Processing the library embeddings...")
end
