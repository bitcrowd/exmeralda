defmodule ExmeraldaWeb.IngestionLive.Index do
  use ExmeraldaWeb, :live_view

  alias Exmeralda.Topics

  @latest_successful_ingestions_limit 10
  @impl true
  def handle_params(params, _url, socket) do
    {:ok, {latest_successful_ingestions, _meta}} =
      Topics.latest_successful_ingestions(%{limit: @latest_successful_ingestions_limit})

    {:ok, {ingestions, meta}} = Topics.list_ingestions(params)

    socket =
      socket
      |> assign(:page_title, "Current Ingestions")
      |> assign(:meta, meta)
      |> stream(:latest_successful_ingestions, latest_successful_ingestions,
        limit: @latest_successful_ingestions_limit,
        reset: true
      )
      |> stream(:ingestions, ingestions, reset: true)

    {:noreply, socket}
  end

  @impl true
  def handle_event("update-filter", params, socket) do
    params = Map.delete(params, "_target")
    {:noreply, push_patch(socket, to: ~p"/ingestions?#{params}")}
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
            {gettext("Ingestions")}
          </h2>
          <.filter_form
            class="grid grid-cols-4 gap-4 p-4"
            fields={[
              state: [
                label: gettext("State"),
                type: "select",
                options: [
                  {"All states", ""},
                  {"Queued", "queued"},
                  {"Preprocessing", "preprocessing"},
                  {"Chunking", "chunking"},
                  {"Embedding", "embedding"},
                  {"Failed", "failed"},
                  {"Ready", "ready"}
                ]
              ]
            ]}
            meta={@meta}
            id="ingestion-filter-form"
          />
          <Flop.Phoenix.table
            items={@streams.ingestions}
            meta={@meta}
            path={~p"/ingestions"}
            opts={[table_attrs: [class: "table"]]}
          >
            <:col :let={{_id, ingestion}} label="Name" field={:name}>{ingestion.library.name}</:col>
            <:col :let={{_id, ingestion}} label="Version" field={:version}>
              {ingestion.library.version}
            </:col>
            <:col :let={{_id, ingestion}} label="State" field={:state}>
              <.ingestion_state_badge state={ingestion.state}>
                {ingestion.state}
              </.ingestion_state_badge>
            </:col>
            <:col :let={{_id, ingestion}} label="Created At" field={:inserted_at}>
              {Calendar.strftime(ingestion.inserted_at, "%Y-%m-%d %H:%M")}
            </:col>
            <:col :let={{_id, ingestion}} label="Updated At" field={:updated_at}>
              {Calendar.strftime(ingestion.updated_at, "%Y-%m-%d %H:%M")}
            </:col>
          </Flop.Phoenix.table>
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
