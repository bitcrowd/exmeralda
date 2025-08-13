defmodule ExmeraldaWeb.Admin.IngestionLive.Show do
  use ExmeraldaWeb, :live_view
  import ExmeraldaWeb.Admin.Helper
  alias Exmeralda.Topics

  @impl true
  def handle_params(params, _url, socket) do
    library = Topics.get_library!(params["library_id"])
    ingestion = Topics.get_ingestion!(params["id"])
    stats = Topics.get_ingestion_stats(ingestion)
    {:ok, {chunks, meta}} = Topics.list_ingestion_chunks(ingestion, params)

    socket =
      socket
      |> assign(:page_title, "Ingestion #{ingestion.id}")
      |> assign(:library, library)
      |> assign(:ingestion, ingestion)
      |> assign(:stats, stats)
      |> assign(:chunks, chunks)
      |> assign(:meta, meta)

    {:noreply, socket}
  end

  @impl true
  def handle_event("update-filter", params, socket) do
    params = Map.delete(params, "_target")

    {:noreply,
     push_patch(socket,
       to:
         ~p"/admin/library/#{socket.assigns.library.id}/ingestion/#{socket.assigns.ingestion.id}?#{params}"
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.navbar_layout user={@current_user}>
      <.breadcrumbs>
        <:items title="Libraries" href={~p"/admin"} icon_name="hero-inbox-stack-micro" />
        <:items title={library_title(@library)} href={~p"/admin/library/#{@library.id}"} />
        <:items
          title={"Ingestion ##{@ingestion.id}"}
          href={~p"/admin/library/#{@library.id}/ingestions/#{@ingestion.id}"}
        />
      </.breadcrumbs>

      <.header title={"Ingestion ##{@ingestion.id} for #{library_title(@library)}"}>
        <.ingestion_state state={@ingestion.state} />
      </.header>

      <div class="stats shadow">
        <.stat icon_name="hero-bolt" title="Total Chunks" value={@stats[:chunks_total]} />

        <.stat
          icon_name="hero-book-open"
          title="Embedded chunks"
          value={@stats[:chunks_embedding]}
          text_variant="text-secondary"
          value_variant="text-secondary"
          total={@stats[:chunks_total]}
        />

        <.stat
          icon_name="hero-book-open"
          title="Chunks from docs"
          value={Keyword.get(@stats[:chunks_type], :docs, 0)}
          text_variant="text-secondary"
          value_variant="text-secondary"
          total={@stats[:chunks_total]}
        />

        <.stat
          icon_name="hero-code-bracket"
          title="Chunks from code"
          value={Keyword.get(@stats[:chunks_type], :code, 0)}
          text_variant="text-secondary"
          value_variant=""
          total={@stats[:chunks_total]}
        />
      </div>

      <.filter_form
        class="grid grid-cols-4 gap-4 p-4"
        fields={[
          type: [label: gettext("Type"), type: "select", options: ["", "code", "docs"]],
          source: [
            label: gettext("Source"),
            op: :ilike_and
          ]
        ]}
        meta={@meta}
        id="chunk-filter-form"
      />
      <Flop.Phoenix.table
        items={@chunks}
        meta={@meta}
        path={~p"/admin/library/#{@library.id}/ingestion/#{@ingestion.id}"}
        opts={[table_attrs: [class: "table"]]}
      >
        <:col :let={chunk} label="Type" field={:type}>{chunk.type}</:col>
        <:col :let={chunk} label="Source" field={:source}>{chunk.source}</:col>
        <:col :let={chunk} label="Content" field={:content}>
          <details>
            <summary>Show</summary>
            {chunk.content}
          </details>
        </:col>
      </Flop.Phoenix.table>

      <.pagination meta={@meta} path={~p"/admin/library/#{@library.id}/ingestion/#{@ingestion.id}"} />
    </.navbar_layout>
    """
  end
end
