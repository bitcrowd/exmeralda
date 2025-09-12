defmodule ExmeraldaWeb.Admin.GenerationPromptLive.New do
  use ExmeraldaWeb, :live_view
  alias Exmeralda.Topics.GenerationPrompts

  @impl true
  def handle_params(_params, _url, socket) do
    socket =
      socket
      |> assign(:page_title, gettext("New Generation Prompt"))
      |> assign(:form, to_form(GenerationPrompts.change_generation_prompt()))

    {:noreply, socket}
  end

  @impl true
  def handle_event("save", %{"generation_prompt" => generation_prompt_params}, socket) do
    case GenerationPrompts.create_generation_prompt(generation_prompt_params) do
      {:ok, _generation_prompt} ->
        {:noreply,
         socket
         |> put_flash(:info, "Generation prompt created successfully")
         |> push_navigate(to: ~p"/admin/generation_prompts")}

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
          title={gettext("Generation Prompts")}
          href={~p"/admin/generation_prompts"}
          icon_name="hero-command-line-micro"
        />
      </.breadcrumbs>

      <.header title={gettext("New Generation Prompt")} />

      <.simple_form for={@form} id="generation_prompt-form" phx-submit="save">
        <.input field={@form[:prompt]} type="textarea" label="Prompt" />
        <:actions>
          <a href={~p"/admin/generation_prompts"} class="btn">{gettext("Cancel")}</a>
        </:actions>
        <:actions>
          <.button phx-disable-with="Saving..." class="btn-primary">{gettext("Save")}</.button>
        </:actions>
      </.simple_form>
    </.admin_nav_layout>
    """
  end
end
