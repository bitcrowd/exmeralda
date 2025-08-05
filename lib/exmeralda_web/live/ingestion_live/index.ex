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
      <article class="max-w-4xl mx-auto p-4">
        <div class="grid grid-cols-1 sm:grid-cols-2 p-4 justify-between">
          <h2 class="text-2xl font-bold">
            {gettext("Ingestions")}
          </h2>
          <.ingestion_state_filter_toggle
            class="justify-self-end"
            state={:ready}
            label={gettext("Only ready")}
            checked={checked?(@meta)}
            meta={@meta}
            id="ingestion-filter-form"
          />
        </div>

        <Flop.Phoenix.table
          items={@streams.ingestions}
          meta={@meta}
          path={~p"/ingestions"}
          opts={[table_attrs: [class: "table md:table-fixed"]]}
        >
          <:col :let={{_id, ingestion}} label="Name" field={:name}>{ingestion.library.name}</:col>
          <:col :let={{_id, ingestion}} label="Version" field={:version}>
            {ingestion.library.version}
          </:col>
          <:col
            :let={{_id, ingestion}}
            label="State"
            field={nil}
            thead_th_attrs={[class: "text-center"]}
            tbody_td_attrs={[class: "text-center"]}
          >
            <.ingestion_state_badge state={ingestion.state}>
              {ingestion.state}
            </.ingestion_state_badge>
          </:col>
        </Flop.Phoenix.table>
        <.pagination meta={@meta} path={~p"/ingestions"} />
      </article>
    </.navbar_layout>
    """
  end

  defp checked?(meta), do: !!Flop.Filter.get(meta.flop.filters, :state)
end
