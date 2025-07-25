defmodule ExmeraldaWeb.IngestionLive.Index do
  use ExmeraldaWeb, :live_view

  alias Exmeralda.Topics

  @impl true
  def handle_params(params, _url, socket) do
    {:ok, {ingestions, meta}} = Topics.latest_ingestions(params)

    socket =
      socket
      |> assign(:page_title, "Current Ingestions")
      |> assign(:ingestions, ingestions)
      |> assign(:meta, meta)

    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.navbar_layout user={@current_user}>
      <.link class="btn m-3" navigate={~p"/chat/start"} title="Back">
        <.icon name="hero-arrow-left" />
      </.link>

      <div class="p-4 gap-8 grid grid-cols-1 lg:grid-cols-[1fr_auto]">
        <article>
          <h2 class="text-2xl font-bold p-4">
            {gettext("Currently Ingesting")}
          </h2>
          <Flop.Phoenix.table
            items={@ingestions}
            meta={@meta}
            path={~p"/ingestions"}
            opts={[table_attrs: [class: "table"]]}
          >
            <:col :let={ingestion} label="Library" field={:library}>{ingestion.library.name}</:col>
            <:col :let={ingestion} label="Version" field={:library}>{ingestion.library.version}</:col>
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
          </Flop.Phoenix.table>

          <.pagination meta={@meta} path={~p"/ingestions"} />
        </article>
        <aside class="order-first lg:order-last">
          <h2 class="text-2xl font-bold p-4">
            {gettext("Latest Library Updates")}
          </h2>

          <ol class="timeline timeline-vertical">
            <li :for={ingestion <- @ingestions} class="group">
              <hr class="bg-success group-first:hidden" />
              <div class="timeline-middle" label="Version">
                <span class="badge badge-success">
                  <.icon name="hero-check-circle" /> v{ingestion.library.version}
                </span>
              </div>
              <div class="timeline-end timeline-box" label="Library">
                {ingestion.library.name}
              </div>
              <hr class="bg-success group-last:hidden" />
            </li>
          </ol>
        </aside>
      </div>
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
