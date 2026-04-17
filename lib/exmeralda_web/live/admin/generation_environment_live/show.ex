defmodule ExmeraldaWeb.Admin.GenerationEnvironmentLive.Show do
  use ExmeraldaWeb, :live_view
  import ExmeraldaWeb.Admin.Helper
  alias Exmeralda.Chats.GenerationEnvironments

  @impl true
  def handle_params(params, _url, socket) do
    generation_environment = GenerationEnvironments.get_generation_environment!(params["id"])

    socket =
      socket
      |> assign(:page_title, "Generation Environment #{generation_environment.id}")
      |> assign(:generation_environment, generation_environment)
      |> assign(
        :current_generation_environment_id,
        GenerationEnvironments.get_current_generation_environment_id()
      )

    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.admin_nav_layout user={@current_user} current_path={@current_path}>
      <.breadcrumbs>
        <:items
          title="Generation Environments"
          href={~p"/admin/generation_environments"}
          icon_name="hero-cube-transparent-micro"
        />
        <:items
          title={@generation_environment.id}
          href={~p"/admin/generation_environments/#{@generation_environment.id}"}
        />
      </.breadcrumbs>

      <.header title={"Generation Environment #{@generation_environment.id}"} />

      <.list>
        <:item title={gettext("ID")}>{@generation_environment.id}</:item>
        <:item title={gettext("Active")}>
          <.active_badge :if={@generation_environment.id == @current_generation_environment_id} />
          <span :if={@generation_environment.id != @current_generation_environment_id}>—</span>
        </:item>
        <:item title={gettext("Updated At")}>{datetime(@generation_environment.updated_at)}</:item>
      </.list>

      <.section title={gettext("Model Config Provider")}>
        <.model_config_provider_details provider={@generation_environment.model_config_provider} />
      </.section>

      <.section title={gettext("System Prompt")}>
        <.system_prompt_details system_prompt={@generation_environment.system_prompt} />
      </.section>

      <.section title={gettext("Generation Prompt")}>
        <.generation_prompt_details generation_prompt={@generation_environment.generation_prompt} />
      </.section>
    </.admin_nav_layout>
    """
  end

  attr :provider, :any, required: true

  defp model_config_provider_details(%{provider: nil} = assigns) do
    ~H"""
    <p class="italic text-sm py-4">—</p>
    """
  end

  defp model_config_provider_details(assigns) do
    ~H"""
    <.list>
      <:item title={gettext("ID")}>{@provider.id}</:item>
      <:item title={gettext("Name")}>{@provider.name}</:item>
      <:item title={gettext("Provider")}>{@provider.provider && @provider.provider.name}</:item>
      <:item title={gettext("Provider Type")}>
        {@provider.provider && @provider.provider.type}
      </:item>
      <:item title={gettext("Model Config")}>
        {@provider.model_config && @provider.model_config.name}
      </:item>
      <:item title={gettext("Inserted At")}>{datetime(@provider.inserted_at)}</:item>
      <:item title={gettext("Updated At")}>{datetime(@provider.updated_at)}</:item>
    </.list>
    """
  end

  attr :system_prompt, :any, required: true

  defp system_prompt_details(%{system_prompt: nil} = assigns) do
    ~H"""
    <p class="italic text-sm py-4">—</p>
    """
  end

  defp system_prompt_details(assigns) do
    ~H"""
    <.list>
      <:item title={gettext("ID")}>{@system_prompt.id}</:item>
      <:item title={gettext("Active")}>
        <.active_badge :if={@system_prompt.active} />
        <span :if={!@system_prompt.active}>—</span>
      </:item>
      <:item title={gettext("Prompt")}>
        <pre class="whitespace-pre-wrap break-words text-xs">{@system_prompt.prompt}</pre>
      </:item>
      <:item title={gettext("Inserted At")}>{datetime(@system_prompt.inserted_at)}</:item>
      <:item title={gettext("Updated At")}>{datetime(@system_prompt.updated_at)}</:item>
    </.list>
    """
  end

  attr :generation_prompt, :any, required: true

  defp generation_prompt_details(%{generation_prompt: nil} = assigns) do
    ~H"""
    <p class="italic text-sm py-4">—</p>
    """
  end

  defp generation_prompt_details(assigns) do
    ~H"""
    <.list>
      <:item title={gettext("ID")}>{@generation_prompt.id}</:item>
      <:item title={gettext("Prompt")}>
        <pre class="whitespace-pre-wrap break-words text-xs">{@generation_prompt.prompt}</pre>
      </:item>
      <:item title={gettext("Inserted At")}>{datetime(@generation_prompt.inserted_at)}</:item>
      <:item title={gettext("Updated At")}>{datetime(@generation_prompt.updated_at)}</:item>
    </.list>
    """
  end
end
