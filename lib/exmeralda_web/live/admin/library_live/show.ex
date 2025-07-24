defmodule ExmeraldaWeb.Admin.LibraryLive.Show do
  use ExmeraldaWeb, :live_view

  alias Exmeralda.Topics

  @impl true
  def handle_params(params, _url, socket) do
    library = Topics.get_library!(params["id"])
    ingestions = Topics.list_ingestions(library)

    socket =
      socket
      |> assign(:page_title, "#{library.name} #{library.version}")
      |> assign(:library, library)
      |> assign(:ingestions, ingestions)

    {:noreply, socket}
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

      <div class="overflow-x-auto">
        <table class="table">
          <thead>
            <tr>
              <th>ID</th>
              <th>State</th>
              <th>Created At</th>
              <th>Updated At</th>
              <th>Actions</th>
            </tr>
          </thead>
          <tbody>
            <tr :for={ingestion <- @ingestions}>
              <td>{ingestion.id}</td>
              <td>
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
              </td>
              <td>{Calendar.strftime(ingestion.inserted_at, "%Y-%m-%d %H:%M")}</td>
              <td>{Calendar.strftime(ingestion.updated_at, "%Y-%m-%d %H:%M")}</td>
              <td>
                <.link
                  class="btn btn-primary btn-sm"
                  navigate={~p"/admin/library/#{@library.id}/ingestion/#{ingestion.id}"}
                >
                  Show
                </.link>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </.navbar_layout>
    """
  end
end
