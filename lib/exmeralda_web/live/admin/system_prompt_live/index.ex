defmodule ExmeraldaWeb.Admin.SystemPromptLive.Index do
  use ExmeraldaWeb, :live_view
  import ExmeraldaWeb.Admin.Helper
  alias Exmeralda.LLM.SystemPrompts

  @impl true
  def handle_params(params, _url, socket) do
    {:ok, {system_prompts, meta}} = SystemPrompts.list_system_prompts(params)

    socket =
      socket
      |> assign(:page_title, gettext("System Prompts"))
      |> assign(:system_prompts, system_prompts)
      |> assign(:meta, meta)
      |> assign(:current_system_prompt_id, current_system_prompt_id())

    {:noreply, socket}
  end

  @impl true
  def handle_event("delete", %{"system-prompt-id" => system_prompt_id}, socket) do
    {:noreply,
     case SystemPrompts.delete_system_prompt(system_prompt_id) do
       :ok ->
         socket
         |> put_flash(:info, gettext("System prompt successfully deleted."))
         |> push_patch(to: ~p"/admin/system_prompts")

       {:error, :system_prompt_used} ->
         socket
         |> put_flash(:error, gettext("System prompt is used and cannot be deleted."))
         |> push_patch(to: ~p"/admin/system_prompts")
     end}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.admin_nav_layout user={@current_user} current_path={@current_path}>
      <.breadcrumbs>
        <:items
          title={gettext("System Prompts")}
          href={~p"/admin/system_prompts"}
          icon_name="hero-chat-bubble-bottom-center-text-micro"
        />
      </.breadcrumbs>

      <.header title={gettext("System Prompts")}>
        <:actions>
          <a href={~p"/admin/system_prompts/new"} class="btn btn-primary">
            <.icon name="hero-plus" />{gettext("Add")}
          </a>
        </:actions>
      </.header>

      <Flop.Phoenix.table
        items={@system_prompts}
        meta={@meta}
        path={~p"/admin/system_prompts"}
        opts={[table_attrs: [class: "table"]]}
      >
        <:col :let={system_prompt} label={gettext("ID")} field={:id}>
          <span>{system_prompt.id}</span>
          <.active_badge :if={system_prompt.id == @current_system_prompt_id} />
        </:col>
        <:col :let={system_prompt} label={gettext("Prompt")} field={:prompt}>
          {system_prompt.prompt}
        </:col>
        <:col :let={system_prompt} label={gettext("Created At")} field={:inserted_at}>
          {datetime(system_prompt.inserted_at)}
        </:col>
        <:col :let={system_prompt} label="Actions">
          <.button
            phx-click="delete"
            phx-value-system-prompt-id={system_prompt.id}
            class={"btn btn-error e2e-delete-system-prompt-#{system_prompt.id}"}
            disabled={!system_prompt.deletable}
          >
            {gettext("Delete")}
          </.button>
        </:col>
      </Flop.Phoenix.table>

      <.pagination meta={@meta} path={~p"/admin/system_prompts"} />
    </.admin_nav_layout>
    """
  end

  defp current_system_prompt_id do
    %{system_prompt_id: system_prompt_id} = Application.fetch_env!(:exmeralda, :llm_config)
    system_prompt_id
  end
end
