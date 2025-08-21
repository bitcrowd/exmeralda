defmodule ExmeraldaWeb.Admin.LibraryLive.Show do
  use ExmeraldaWeb, :live_view
  import ExmeraldaWeb.Admin.Helper
  import ExmeraldaWeb.Shared.Helper
  alias Exmeralda.{Topics, Chats}

  @impl true
  def handle_params(params, _url, socket) do
    library = Topics.get_library!(params["id"])
    chat_sessions = Chats.list_sessions_for_library(library.id)
    {:ok, {ingestions, meta}} = Topics.list_ingestions(library, params)

    socket =
      socket
      |> assign(:page_title, library_title(library))
      |> assign(:library, library)
      |> assign(:ingestions, ingestions)
      |> assign(:chat_sessions, chat_sessions)
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
    %{library: library} = socket.assigns

    {:noreply,
     case Topics.reingest_library(library.id) do
       {:ok, _ingestion} ->
         socket
         |> put_flash(:info, gettext("Reingestion is now in queue!"))
         |> push_patch(to: ~p"/admin/library/#{library.id}")

       {:error, {:not_found, _}} ->
         socket
         |> put_flash(:error, gettext("Library not found"))
         |> push_navigate(to: ~p"/admin")
     end}
  end

  @impl true
  def handle_event("delete", _params, socket) do
    %{library: library} = socket.assigns

    socket =
      case Topics.delete_library(library.id) do
        {:ok, _} ->
          socket
          |> put_flash(:info, gettext("Library successfully deleted!"))
          |> push_navigate(to: ~p"/admin")

        {:error, :library_has_chats} ->
          socket
          |> put_flash(:error, gettext("Library has chats and cannot be deleted."))
          |> push_patch(to: ~p"/admin/library/#{library.id}")
      end

    {:noreply, socket}
  end

  def handle_event("mark-as-active", %{"ingestion-id" => ingestion_id}, socket) do
    %{library: library} = socket.assigns

    socket =
      case Topics.mark_ingestion_as_active(ingestion_id) do
        {:ok, ingestion} ->
          socket
          |> put_flash(:info, gettext("Ingestion was successfully marked active."))
          |> push_patch(to: ~p"/admin/library/#{library.id}")

        {:error, error} when error in [:ingestion_already_active, :ingestion_invalid_state] ->
          push_patch(socket, to: ~p"/admin/library/#{library.id}")

        {:error, {:not_found, _}} ->
          socket
          |> put_flash(:error, gettext("Ingestion was deleted and cannot be marked active."))
          |> push_patch(to: ~p"/admin/library/#{library.id}")
      end

    {:noreply, socket}
  end

  def handle_event("mark-as-inactive", %{"ingestion-id" => ingestion_id}, socket) do
    %{library: library} = socket.assigns

    socket =
      case Topics.mark_ingestion_as_inactive(ingestion_id) do
        {:ok, ingestion} ->
          socket
          |> put_flash(:info, gettext("Ingestion was successfully marked inactive."))
          |> push_patch(to: ~p"/admin/library/#{library.id}")

        {:error, error} when error in [:ingestion_already_inactive, :ingestion_invalid_state] ->
          push_patch(socket, to: ~p"/admin/library/#{library.id}")

        {:error, {:not_found, _}} ->
          socket
          |> put_flash(:error, gettext("Ingestion was deleted and cannot be marked inactive."))
          |> push_patch(to: ~p"/admin/library/#{library.id}")
      end

    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    assigns = assign_new(assigns, :library_deletable?, fn -> library_deletable?(assigns) end)

    ~H"""
    <.navbar_layout user={@current_user}>
      <.breadcrumbs>
        <:items title="Libraries" href={~p"/admin"} icon_name="hero-inbox-stack-micro" />
        <:items title={library_title(@library)} href={~p"/admin/library/#{@library.id}"} />
      </.breadcrumbs>

      <.header title={"Library #{library_title(@library)}"}>
        <:actions>
          <div
            class={[!@library_deletable? && "tooltip tooltip-left"]}
            data-tip={gettext("This library is used in chats.")}
          >
            <.button
              class="btn btn-error"
              disabled={!@library_deletable?}
              phx-click="delete"
              data-confirm="This will delete all ingestions associated to this library as well! Are you sure?"
            >
              <.icon name="hero-trash" /> Delete
            </.button>
          </div>
        </:actions>
      </.header>

      <.list>
        <:item title={gettext("ID")}>{@library.id}</:item>
        <:item title={gettext("Name")}>{@library.name}</:item>
        <:item title={gettext("Version")}>{@library.version}</:item>
        <:item title={gettext("Chat Sessions Count")}>{length(@chat_sessions)}</:item>
        <:item title={gettext("Inserted At")}>{datetime(@library.inserted_at)}</:item>
        <:item title={gettext("Updated At")}>{datetime(@library.updated_at)}</:item>
      </.list>

      <.section title={gettext("Ingestions")}>
        <:actions>
          <.button class="btn btn-warning" phx-click="reingest">
            <.icon name="hero-arrow-path" /> Re-Ingest
          </.button>
        </:actions>

        <.filter_form
          class="grid grid-cols-4 gap-4 pb-4 mt-4"
          fields={[
            state: [
              label: gettext("State"),
              type: "select",
              options: [
                {"All states", ""},
                {"Queued", "queued"},
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
          <:col :let={ingestion} label="ID" field={:id}>
            {ingestion.id}
            <.ingestion_active_badge :if={ingestion.active} active={ingestion.active} />
          </:col>
          <:col :let={ingestion} label="State" field={:state}>
            <.ingestion_state_badge state={ingestion.state} />
          </:col>
          <:col :let={ingestion} label="Created At" field={:inserted_at}>
            {datetime(ingestion.inserted_at)}
          </:col>
          <:col :let={ingestion} label="Updated At" field={:updated_at}>
            {datetime(ingestion.updated_at)}
          </:col>
          <:col :let={ingestion} label="Actions">
            <.link
              class="btn btn-primary btn-sm"
              navigate={~p"/admin/library/#{@library.id}/ingestions/#{ingestion.id}"}
            >
              Show
            </.link>
            <.button
              :if={ingestion.state == :ready && !ingestion.active}
              class="btn btn-primary btn-soft btn-sm ml-2"
              phx-click="mark-as-active"
              phx-value-ingestion-id={ingestion.id}
            >
              <.icon name="hero-check-circle-micro" class="scale-75" />
              {gettext("Mark as active")}
            </.button>
            <.button
              :if={ingestion.state == :ready && ingestion.active}
              class="btn btn-secondary btn-soft btn-sm ml-2"
              phx-click="mark-as-inactive"
              phx-value-ingestion-id={ingestion.id}
            >
              <.icon name="hero-no-symbol-micro" class="scale-75" />
              {gettext("Mark as inactive")}
            </.button>
          </:col>
        </Flop.Phoenix.table>

        <.pagination meta={@meta} path={~p"/admin/library/#{@library.id}"} />
      </.section>
    </.navbar_layout>
    """
  end

  defp library_deletable?(assigns) do
    %{chat_sessions: chat_sessions} = assigns
    Enum.empty?(chat_sessions)
  end
end
