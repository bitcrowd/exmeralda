defmodule ExmeraldaWeb.IngestionLive.Index do
  use ExmeraldaWeb, :live_view

  alias Exmeralda.Topics

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     stream_configure(socket, :ingestions,
       dom_id: fn {ingestion, _job} -> "ingestions-#{ingestion.id}" end
     )}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:ok, {ingestions_with_job, meta}} = Topics.list_ingestions_with_latest_job(params)

    socket =
      socket
      |> assign(:page_title, "Current Ingestions")
      |> assign(:meta, meta)
      |> stream(:ingestions, ingestions_with_job, reset: true)

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

        <div class="overflow-x-auto">
          <Flop.Phoenix.table
            items={@streams.ingestions}
            meta={@meta}
            path={~p"/ingestions"}
            opts={[table_attrs: [class: "table md:table-fixed"]]}
          >
            <:col :let={{_id, {ingestion, _job}}} label="Name" field={:name}>
              {ingestion.library.name}
            </:col>
            <:col :let={{_id, {ingestion, _job}}} label="Version" field={:version}>
              {ingestion.library.version}
            </:col>
            <:col
              :let={{_id, {ingestion, _job}}}
              label="State"
              field={nil}
              thead_th_attrs={[class: "text-center"]}
              tbody_td_attrs={[class: "text-center"]}
            >
              <.ingestion_state_badge state={ingestion.state}>
                {ingestion.state}
              </.ingestion_state_badge>
            </:col>
            <:col :let={{_id, {_ingestion, job}}}>
              <span :if={job && job.state == "executing"} class="loading loading-spinner" />
              <div
                :if={job && job.state in ["discarded", "cancelled"]}
                class="flex flex-row items-center gap-2 text-error "
              >
                <.icon name="hero-exclamation-circle" />
                {gettext("We're investigating")}
              </div>
            </:col>
          </Flop.Phoenix.table>
          <.pagination meta={@meta} path={~p"/ingestions"} />
        </div>
      </article>
    </.navbar_layout>
    """
  end

  defp checked?(meta), do: !!Flop.Filter.get(meta.flop.filters, :state)
end
