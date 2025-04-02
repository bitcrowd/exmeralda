defmodule ExmeraldaWeb.Admin.LibraryLive.Show do
  use ExmeraldaWeb, :live_view

  alias Exmeralda.Topics

  @impl true
  def handle_params(params, _url, socket) do
    library = Topics.get_library!(params["id"])
    stats = Topics.get_library_stats(library)
    {:ok, {chunks, meta}} = Topics.list_chunks(library, params)

    socket =
      socket
      |> assign(:page_title, "#{library.name} #{library.version}")
      |> assign(:library, library)
      |> assign(:stats, stats)
      |> assign(:chunks, chunks)
      |> assign(:meta, meta)

    {:noreply, socket}
  end

  @impl true
  def handle_event("update-filter", params, socket) do
    params = Map.delete(params, "_target")
    {:noreply, push_patch(socket, to: ~p"/admin/library/#{socket.assigns.library.id}?#{params}")}
  end

  @impl true
  def handle_event("reingest", _params, socket) do
    Topics.reingest_library(socket.assigns.library)
    {:noreply, put_flash(socket, :info, gettext("Reingestion is now in queue!"))}
  end

  @impl true
  def handle_event("delete", _params, socket) do
    Topics.delete_library(socket.assigns.library)

    {:noreply,
     put_flash(socket, :info, gettext("Library successfully deleted!"))
     |> push_navigate(to: ~p"/admin")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.navbar_layout user={@current_user}>
      <.link class="btn m-3" navigate={~p"/admin"} title="Back">
        <.icon name="hero-arrow-left" />
      </.link>
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
      <ul class="flex p-5 gap-3">
        <li>
          <.link
            class="btn btn-warning"
            phx-click="reingest"
            data-confirm="This will delete all source references to the library! Are you sure?"
          >
            <.icon name="hero-arrow-path" /> Re-Ingest
          </.link>
        </li>
        <li>
          <.link
            class="btn btn-error"
            phx-click="delete"
            data-confirm="This will delete all chats associated to this library as well! Are you sure?"
          >
            <.icon name="hero-trash" /> Delete
          </.link>
        </li>
      </ul>
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
        path={~p"/admin/library/#{@library.id}"}
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

      <.pagination meta={@meta} path={~p"/admin/library/#{@library.id}"} />
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
