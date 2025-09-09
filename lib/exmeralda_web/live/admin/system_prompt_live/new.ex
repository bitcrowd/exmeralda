defmodule ExmeraldaWeb.Admin.SystemPromptLive.New do
  use ExmeraldaWeb, :live_view
  alias Exmeralda.LLM.SystemPrompts

  @impl true
  def handle_params(_params, _url, socket) do
    socket =
      socket
      |> assign(:page_title, gettext("New System Prompt"))
      |> assign(:form, to_form(SystemPrompts.change_system_prompt()))

    {:noreply, socket}
  end

  @impl true
  def handle_event("save", %{"system_prompt" => system_prompt_params}, socket) do
    case SystemPrompts.create_system_prompt(system_prompt_params) do
      {:ok, _system_prompt} ->
        {:noreply,
         socket
         |> put_flash(:info, "System prompt created successfully")
         |> push_navigate(to: ~p"/admin/system_prompts")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.admin_nav_layout user={@current_user} current_path={@current_path}>
      <.breadcrumbs>
        <:items
          title={gettext("System Prompts")}
          href={~p"/admin/system_prompts"}
          icon_name="hero-command-line-micro"
        />
      </.breadcrumbs>

      <.header title={gettext("New System Prompt")} />

      <.simple_form for={@form} id="system_prompt-form" phx-submit="save">
        <.input field={@form[:prompt]} type="textarea" label="Prompt" />
        <:actions>
          <a href={~p"/admin/system_prompts"} class="btn">{gettext("Cancel")}</a>
        </:actions>
        <:actions>
          <.button phx-disable-with="Saving..." class="btn-primary">{gettext("Save")}</.button>
        </:actions>
      </.simple_form>
    </.admin_nav_layout>
    """
  end
end
