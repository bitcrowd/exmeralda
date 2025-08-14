defmodule ExmeraldaWeb.ChatLive.Ingestions.Index do
  use ExmeraldaWeb, :live_component
  import ExmeraldaWeb.Shared.Helper
  alias Exmeralda.Topics

  @impl true
  def update(%{event: :ingestion_created, ingestion: ingestion}, socket) do
    ingestions = socket.assigns.ingestions
    {:ok, assign(socket, :ingestions, [{ingestion, nil} | ingestions])}
  end

  def update(%{event: :ingestion_state_updated, ingestion: updated_ingestion}, socket) do
    ingestions =
      socket.assigns.ingestions
      |> Enum.map(fn {ingestion, job} ->
        if ingestion.id == updated_ingestion.id,
          do: {updated_ingestion, nil},
          else: {ingestion, job}
      end)

    {:ok, assign(socket, :ingestions, ingestions)}
  end

  def update(params, socket) do
    {:ok, {ingestions_with_job, meta}} = Topics.list_ingestions_with_latest_job(params)

    socket =
      socket
      |> assign(:page_title, "Latest Library Updates")
      |> assign(:meta, meta)
      |> assign(:ingestions, ingestions_with_job)

    {:ok, socket}
  end

  @impl true
  def handle_event("update-filter", params, socket) do
    params = Map.delete(params, "_target")
    {:noreply, push_patch(socket, to: ~p"/ingestions?#{params}")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <article class="max-w-4xl mx-auto p-4">
      <div class="grid grid-cols-1 sm:grid-cols-2 p-4 justify-between">
        <h2 class="text-2xl font-bold">
          {gettext("Latest Library Updates")}
        </h2>
        <%!-- <.ingestion_state_filter_toggle
          class="justify-self-end"
          state={:ready}
          label={gettext("Only ready")}
          checked={checked?(@meta)}
          meta={@meta}
          id="ingestion-filter-form"
          target={@myself}
        /> --%>
      </div>

      <div class="overflow-x-auto">
        <Flop.Phoenix.table
          items={@ingestions}
          meta={@meta}
          path={~p"/ingestions"}
          opts={[table_attrs: [class: "table md:table-fixed"]]}
        >
          <:col :let={{ingestion, _job}} label="Name" field={:name}>
            {ingestion.library.name}
          </:col>
          <:col :let={{ingestion, _job}} label="Version" field={:version}>
            {ingestion.library.version}
          </:col>
          <:col
            :let={{ingestion, _job}}
            label="State"
            field={nil}
            thead_th_attrs={[class: "text-center"]}
            tbody_td_attrs={[class: "text-center"]}
          >
            <.ingestion_state_badge state={ingestion.state} />
          </:col>
          <%!-- <:col :let={{_ingestion, job}}>
            <span :if={job && job.state == "executing"} class="loading loading-spinner" />
            <div
              :if={job && job.state in ["discarded", "cancelled"]}
              class="flex flex-row items-center gap-2 text-error "
            >
              <.icon name="hero-exclamation-circle" />
              {gettext("We're investigating")}
            </div>
          </:col> --%>
        </Flop.Phoenix.table>
        <.pagination meta={@meta} path={~p"/ingestions"} />
      </div>
    </article>
    """
  end

  defp checked?(meta), do: !!Flop.Filter.get(meta.flop.filters, :state)

  #   attr :id, :string, default: nil
  #   attr :target, :string, default: nil
  #   attr :on_change, :string, default: "update-filter"

  #   attr :meta, Flop.Meta, required: true
  #   attr :state, :atom, required: true
  #   attr :name, :any
  #   attr :label, :string, default: nil
  #   attr :checked, :boolean, doc: "the checked flag for checkbox inputs"

  #   attr :rest, :global

  #   def ingestion_state_filter_toggle(%{meta: meta} = assigns) do
  #     assigns =
  #       assigns
  #       |> assign(form: Phoenix.Component.to_form(meta), meta: nil)
  #       |> assign_new(:checked, fn ->
  #         Phoenix.HTML.Form.normalize_value("checkbox", assigns[:value])
  #       end)

  #     ~H"""
  #     <.form
  #       for={@form}
  #       id={@id}
  #       phx-target={@target}
  #       phx-change={@on_change}
  #       phx-submit={@on_change}
  #       {@rest}
  #     >
  #       <.filter_fields :let={i} form={@form} fields={[:state]}>
  #         <div>
  #           <label class="flex items-center gap-4 text-sm leading-6">
  #             {@label}
  #             <input type="hidden" name={i.field.name} value="false" disabled={@rest[:disabled]} />
  #             <input
  #               type="checkbox"
  #               id={i.field.id}
  #               name={i.field.name}
  #               value={@state}
  #               checked={@checked}
  #               class="toggle toggle-success toggle-lg"
  #             />
  #           </label>
  #         </div>
  #       </.filter_fields>
  #     </.form>
  #     """
  #   end
end
