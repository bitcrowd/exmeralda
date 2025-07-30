defmodule ExmeraldaWeb.IngestionLive.Index do
  use ExmeraldaWeb, :live_view

  alias Exmeralda.Topics

  @impl true
  def handle_params(params, _url, socket) do
    {:ok, {ingestions, meta}} = Topics.list_ingestions(params)

    socket =
      socket
      |> assign(:page_title, "Current Ingestions")
      |> assign(:meta, meta)
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
    </.navbar_layout>
    """
  end
end
