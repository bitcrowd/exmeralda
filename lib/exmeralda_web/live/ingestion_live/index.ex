defmodule ExmeraldaWeb.IngestionLive.Index do
  use ExmeraldaWeb, :live_view

  alias Exmeralda.Topics

  @latest_successful_ingestions_limit 10
  @impl true
  def handle_params(_params, _url, socket) do
    {:ok, {latest_successful_ingestions, _meta}} =
      Topics.latest_successful_ingestions(%{limit: @latest_successful_ingestions_limit})

    ingestions = Topics.list_not_ready_ingestions()

    socket =
      socket
      |> assign(:page_title, "Current Ingestions")
      |> stream(:latest_successful_ingestions, latest_successful_ingestions,
        limit: @latest_successful_ingestions_limit,
        reset: true
      )
      |> stream(:ingestions, ingestions, reset: true)

    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.navbar_layout user={@current_user}>
      <.link class="btn m-3" navigate={~p"/chat/start"} title="Back">
        <.icon name="hero-arrow-left" />
      </.link>

      <div class="p-4 gap-8 grid grid-cols-1 lg:grid-cols-[1fr_auto]">
        <article>
          <h2 class="text-2xl font-bold p-4">
            {gettext("Currently Ingesting")}
          </h2>
          <div class="overflow-x-auto">
            <table class="table">
              <thead>
                <th>{gettext("Library")}</th>
                <th>{gettext("Version")}</th>
                <th>{gettext("State")}</th>
              </thead>
              <tbody id="ingestions" phx-update="stream">
                <tr :for={{dom_id, ingestion} <- @streams.ingestions} id={dom_id}>
                  <td>{ingestion.library.name}</td>
                  <td>{ingestion.library.version}</td>
                  <td>
                    <.ingestion_state_badge state={ingestion.state}>
                      {ingestion.state}
                    </.ingestion_state_badge>
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </article>
        <aside class="order-first lg:order-last">
          <h2 class="text-2xl font-bold p-4">
            {gettext("Latest Library Updates")}
          </h2>

          <div class="overflow-x-auto">
            <ol class="timeline timeline-vertical">
              <li :for={{_id, ingestion} <- @streams.latest_successful_ingestions} class="group">
                <hr class="bg-success group-first:hidden" />
                <div class="timeline-middle" label="Version">
                  <span class="badge badge-success">
                    <.icon name="hero-check-circle" /> v{ingestion.library.version}
                  </span>
                </div>
                <div class="timeline-end timeline-box" label="Library">
                  {ingestion.library.name}
                </div>
                <hr class="bg-success group-last:hidden" />
              </li>
            </ol>
          </div>
        </aside>
      </div>
    </.navbar_layout>
    """
  end

  def percent(%{total: 0} = assigns) do
    ~H"0%"
  end

  def percent(%{total: total, value: value} = assigns) do
    assigns = assign(assigns, percent: div(value * 100, total))

    ~H"{@percent}%"
  end
end
