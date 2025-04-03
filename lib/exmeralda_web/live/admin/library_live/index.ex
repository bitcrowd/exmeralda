defmodule ExmeraldaWeb.Admin.LibraryLive.Index do
  use ExmeraldaWeb, :live_view

  alias Exmeralda.Topics

  @impl true
  def handle_params(params, _url, socket) do
    {:ok, {libraries, meta}} = Topics.list_libraries(params)

    socket =
      socket
      |> assign(:page_title, gettext("Libraries"))
      |> assign(:libraries, libraries)
      |> assign(:meta, meta)

    {:noreply, socket}
  end

  @impl true
  def handle_event("update-filter", params, socket) do
    params = Map.delete(params, "_target")
    {:noreply, push_patch(socket, to: ~p"/admin?#{params}")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.navbar_layout user={@current_user}>
      <.filter_form
        class="grid grid-cols-4 gap-4 p-4"
        fields={[
          name: [
            label: gettext("Name"),
            op: :ilike_and
          ],
          version: [
            label: gettext("Version"),
            op: :ilike_and
          ]
        ]}
        meta={@meta}
        id="library-filter-form"
      />
      <Flop.Phoenix.table
        items={@libraries}
        meta={@meta}
        path={~p"/admin"}
        opts={[table_attrs: [class: "table"]]}
      >
        <:col :let={library} label="Name" field={:name}>{library.name}</:col>
        <:col :let={library} label="Version" field={:version}>{library.version}</:col>
        <:col :let={library} label="Actions">
          <.link class="btn btn-primary" navigate={~p"/admin/library/#{library.id}"}>
            {gettext("Show")}
          </.link>
        </:col>
      </Flop.Phoenix.table>

      <.pagination meta={@meta} path={~p"/admin"} />
    </.navbar_layout>
    """
  end
end
