defmodule ExmeraldaWeb.Admin.GenerationEnvironmentLive.Index do
  use ExmeraldaWeb, :live_view
  import ExmeraldaWeb.Admin.Helper
  alias Exmeralda.Chats.GenerationEnvironments

  @impl true
  def handle_params(params, _url, socket) do
    {:ok, {generation_environments, meta}} =
      GenerationEnvironments.list_generation_environments(params)

    socket =
      socket
      |> assign(:page_title, gettext("Generation Environments"))
      |> assign(:generation_environments, generation_environments)
      |> assign(:meta, meta)
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
      </.breadcrumbs>

      <.header title={gettext("Generation Environments")} />

      <Flop.Phoenix.table
        items={@generation_environments}
        meta={@meta}
        path={~p"/admin/generation_environments"}
        opts={[table_attrs: [class: "table"]]}
      >
        <:col :let={env} label="ID" field={:id}>
          {env.id}
          <.active_badge :if={env.id == @current_generation_environment_id} />
        </:col>
        <:col :let={env} label="Model">{model_name(env)}</:col>
        <:col :let={env} label="System Prompt">
          {truncate(env.system_prompt && env.system_prompt.prompt)}
        </:col>
        <:col :let={env} label="Generation Prompt">
          {truncate(env.generation_prompt && env.generation_prompt.prompt)}
        </:col>
        <:col :let={env} label="Actions">
          <.link class="btn btn-primary" navigate={~p"/admin/generation_environments/#{env.id}"}>
            {gettext("Show")}
          </.link>
        </:col>
      </Flop.Phoenix.table>

      <.pagination meta={@meta} path={~p"/admin/generation_environments"} />
    </.admin_nav_layout>
    """
  end

  defp model_name(%{model_config_provider: %{name: name}}) when is_binary(name), do: name
  defp model_name(_), do: "—"

  defp truncate(nil), do: "—"

  defp truncate(text) when is_binary(text) do
    if String.length(text) > 60 do
      String.slice(text, 0, 60) <> "…"
    else
      text
    end
  end
end
