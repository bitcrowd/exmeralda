defmodule ExmeraldaWeb.Admin.LibraryLive.Show do
  use ExmeraldaWeb, :live_view

  alias Exmeralda.Topics

  @impl true
  def handle_params(params, _url, socket) do
    library = Topics.get_library!(params["id"])
    {:ok, {ingestions, meta}} = Topics.list_ingestions_for_library(library, params)

    socket =
      socket
      |> assign(:page_title, "#{library.name} #{library.version}")
      |> assign(:library, library)
      |> assign(:ingestions, ingestions)
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

      <h2 class="text-2xl font-bold p-4">Ingestions for {@library.name} {@library.version}</h2>

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
        items={@ingestions}
        meta={@meta}
        path={~p"/admin/library/#{@library.id}"}
        opts={[table_attrs: [class: "table"]]}
      >
        <:col :let={ingestion} label="ID" field={:id}>{ingestion.id}</:col>
        <:col :let={ingestion} label="State" field={:state}>
          <span class={[
            "badge",
            case ingestion.state do
              :ready -> "badge-success"
              :failed -> "badge-error"
              :queued -> "badge-info"
              _ -> "badge-warning"
            end
          ]}>
            {ingestion.state}
          </span>
        </:col>
        <:col :let={ingestion} label="Created At" field={:inserted_at}>
          {Calendar.strftime(ingestion.inserted_at, "%Y-%m-%d %H:%M")}
        </:col>
        <:col :let={ingestion} label="Updated At" field={:updated_at}>
          {Calendar.strftime(ingestion.updated_at, "%Y-%m-%d %H:%M")}
        </:col>
        <:col :let={ingestion} label="Actions">
          <.link
            class="btn btn-primary btn-sm"
            navigate={~p"/admin/library/#{@library.id}/ingestion/#{ingestion.id}"}
          >
            Show
          </.link>
        </:col>
      </Flop.Phoenix.table>

      <.pagination meta={@meta} path={~p"/admin/library/#{@library.id}"} />
    </.navbar_layout>
    """
  end
end
