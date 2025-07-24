defmodule ExmeraldaWeb.Admin.IngestionLive.Show do
  use ExmeraldaWeb, :live_view

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
      <.link class="btn m-3" navigate={~p"/admin/library/#{@library.id}"} title="Back">
        <.icon name="hero-arrow-left" />
      </.link>

      <h2 class="text-2xl font-bold p-4">
        Ingestion #{@ingestion.id} for {@library.name} {@library.version}
      </h2>

      <div class="stats shadow">
        <div class="stat">
          <div class="stat-figure text-primary">
            <.icon name="hero-bolt" />
          </div>
          <div class="stat-title">Total Chunks</div>
          <div class="stat-value text-primary">{total = @stats[:chunks_total]}</div>
        </div>

        <div class="stat">
          <div class="stat-figure text-secondary">
            <.icon name="hero-book-open" />
          </div>
          <div class="stat-title">Embedded chunks</div>
          <div class="stat-value text-secondary">
            {embedding = @stats[:chunks_embedding]}
            <div class="stat-desc">
              <.percent value={embedding} total={total} />
            </div>
          </div>
        </div>

        <div class="stat">
          <div class="stat-figure text-secondary">
            <.icon name="hero-book-open" />
          </div>
          <div class="stat-title">Chunks from docs</div>
          <div class="stat-value text-secondary">
            {docs = Keyword.get(@stats[:chunks_type], :docs, 0)}
            <div class="stat-desc">
              <.percent value={docs} total={total} />
            </div>
          </div>
        </div>

        <div class="stat">
          <div class="stat-figure text-secondary">
            <.icon name="hero-code-bracket" />
          </div>
          <div class="stat-title">Chunks from code</div>
          <div class="stat-value">
            {code = Keyword.get(@stats[:chunks_type], :code, 0)}
          </div>
          <div class="stat-desc">
            <.percent value={code} total={total} />
          </div>
        </div>
      </div>

      <.filter_form
        class="grid grid-cols-4 gap-4 p-4"
        fields={[
          type: [label: gettext("Type"), type: "select", options: ["code", "docs"]],
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

  def percent(%{total: 0} = assigns) do
    ~H"0%"
  end

  def percent(%{total: total, value: value} = assigns) do
    assigns = assign(assigns, percent: div(value * 100, total))

    ~H"{@percent}%"
  end
end
