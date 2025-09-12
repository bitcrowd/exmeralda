defmodule ExmeraldaWeb.Admin.GenerationPromptLive.Index do
  use ExmeraldaWeb, :live_view
  import ExmeraldaWeb.Admin.Helper
  alias Exmeralda.Topics.GenerationPrompts

  @impl true
  def handle_params(params, _url, socket) do
    {:ok, {generation_prompts, meta}} = GenerationPrompts.list_generation_prompts(params)

    socket =
      socket
      |> assign(:page_title, gettext("System Prompts"))
      |> assign(:generation_prompts, generation_prompts)
      |> assign(:meta, meta)
      |> assign(:current_generation_prompt_id, current_generation_prompt_id())

    {:noreply, socket}
  end

  @impl true
  def handle_event("delete", %{"generation-prompt-id" => generation_prompt_id}, socket) do
    {:noreply,
     case GenerationPrompts.delete_generation_prompt(generation_prompt_id) do
       :ok ->
         socket
         |> put_flash(:info, gettext("Generation prompt successfully deleted."))
         |> push_patch(to: ~p"/admin/generation_prompts")

       {:error, :generation_prompt_used} ->
         socket
         |> put_flash(:error, gettext("Generation prompt is used and cannot be deleted."))
         |> push_patch(to: ~p"/admin/generation_prompts")
     end}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.admin_nav_layout user={@current_user} current_path={@current_path}>
      <.breadcrumbs>
        <:items
          title={gettext("Generation Prompts")}
          href={~p"/admin/generation_prompts"}
          icon_name="hero-command-line-micro"
        />
      </.breadcrumbs>

      <.header title={gettext("Generation Prompts")}>
        <:actions>
          <a href={~p"/admin/generation_prompts/new"} class="btn btn-primary">
            <.icon name="hero-plus" />{gettext("Add")}
          </a>
        </:actions>
      </.header>

      <Flop.Phoenix.table
        items={@generation_prompts}
        meta={@meta}
        path={~p"/admin/generation_prompts"}
        opts={[table_attrs: [class: "table"]]}
      >
        <:col :let={generation_prompt} label={gettext("ID")} field={:id}>
          <span>{generation_prompt.id}</span>
          <.active_badge :if={generation_prompt.id == @current_generation_prompt_id} />
        </:col>
        <:col :let={generation_prompt} label={gettext("Prompt")} field={:prompt}>
          {generation_prompt.prompt}
        </:col>
        <:col :let={generation_prompt} label={gettext("Created At")} field={:inserted_at}>
          {datetime(generation_prompt.inserted_at)}
        </:col>
        <:col :let={generation_prompt} label="Actions">
          <.button
            phx-click="delete"
            phx-value-generation-prompt-id={generation_prompt.id}
            class={"btn btn-error e2e-delete-generation-prompt-#{generation_prompt.id}"}
            disabled={!generation_prompt.deletable}
          >
            {gettext("Delete")}
          </.button>
        </:col>
      </Flop.Phoenix.table>

      <.pagination meta={@meta} path={~p"/admin/generation_prompts"} />
    </.admin_nav_layout>
    """
  end

  defp current_generation_prompt_id do
    %{generation_prompt_id: generation_prompt_id} =
      Application.fetch_env!(:exmeralda, :llm_config)

    generation_prompt_id
  end
end
