defmodule ExmeraldaWeb.Admin.IngestionLive.Show do
  use ExmeraldaWeb, :live_view
  import ExmeraldaWeb.Admin.Helper
  import ExmeraldaWeb.Shared.Helper
  alias Exmeralda.{Topics, Chats}

  @impl true
  def handle_params(params, _url, socket) do
    library = Topics.get_library!(params["library_id"])
    ingestion = Topics.get_ingestion!(params["id"], preloads: [:job])
    stats = Topics.get_ingestion_stats(ingestion)
    embedding_job_stats = Topics.get_embedding_chunks_jobs(ingestion)
    {:ok, {chunks, meta}} = Topics.list_chunks_for_ingestion(ingestion, params)
    chat_sessions = Chats.list_sessions_for_ingestion(ingestion.id)

    socket =
      socket
      |> assign(:page_title, "Ingestion #{ingestion.id}")
      |> assign(:library, library)
      |> assign(:ingestion, ingestion)
      |> assign(:stats, stats)
      |> assign(:embedding_job_stats, embedding_job_stats)
      |> assign(:chunks, chunks)
      |> assign(:meta, meta)
      |> assign(:chat_sessions, chat_sessions)

    {:noreply, socket}
  end

  @impl true
  def handle_event("update-filter", params, socket) do
    params = Map.delete(params, "_target")

    {:noreply,
     push_patch(socket,
       to:
         ~p"/admin/library/#{socket.assigns.library.id}/ingestions/#{socket.assigns.ingestion.id}?#{params}"
     )}
  end

  def handle_event("delete", _params, socket) do
    %{ingestion: ingestion} = socket.assigns

    socket =
      case Topics.delete_ingestion(ingestion.id) do
        {:ok, _} ->
          socket
          |> put_flash(:info, gettext("Ingestion successfully deleted!"))
          |> push_navigate(to: ~p"/admin/library/#{ingestion.library_id}")

        {:error, :ingestion_has_chats} ->
          socket
          |> put_flash(:error, gettext("Ingestion has chats and cannot be deleted."))
          |> push_patch(to: ~p"/admin/library/#{ingestion.library_id}/ingestions/#{ingestion.id}")
      end

    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    assigns = assign_new(assigns, :ingestion_deletable?, fn -> ingestion_deletable?(assigns) end)

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
        <.ingestion_state_badge state={@ingestion.state} />
        <:actions>
          <div
            class={[!@ingestion_deletable? && "tooltip tooltip-left"]}
            data-tip={gettext("This ingestion is used in chats.")}
          >
            <.button
              class="btn btn-error"
              phx-click="delete"
              disabled={!@ingestion_deletable?}
              data-confirm="This will delete all chunks associated to this ingestion. Are you sure?"
            >
              <.icon name="hero-trash" /> Delete
            </.button>
          </div>
        </:actions>
      </.header>

      <.list>
        <:item title={gettext("ID")}>{@ingestion.id}</:item>
        <:item title={gettext("Current Oban Job")}>
          <%= if @ingestion.job_id do %>
            <div>
              <.ingestion_step ingestion={@ingestion} embedding_job_stats={@embedding_job_stats} />
              <a class="link pr-4" href={~p"/oban/jobs/#{@ingestion.job_id}"}>
                View job {@ingestion.job_id}
              </a>
              <.ingestion_job_state state={@ingestion.job.state} />
            </div>
          <% else %>
            <.empty />
          <% end %>
        </:item>
        <:item title={gettext("Chat Sessions Count")}>{length(@chat_sessions)}</:item>
        <:item title={gettext("Inserted At")}>{datetime(@ingestion.inserted_at)}</:item>
        <:item title={gettext("Updated At")}>{datetime(@ingestion.updated_at)}</:item>
      </.list>

      <div class="stats shadow mt-4">
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
        path={~p"/admin/library/#{@library.id}/ingestions/#{@ingestion.id}"}
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

      <.pagination meta={@meta} path={~p"/admin/library/#{@library.id}/ingestions/#{@ingestion.id}"} />
    </.navbar_layout>
    """
  end

  defp ingestion_deletable?(assigns) do
    %{ingestion: ingestion, chat_sessions: chat_sessions} = assigns
    ingestion.state in [:failed, :ready] && Enum.empty?(chat_sessions)
  end
end
