defmodule ExmeraldaWeb.Admin.ProviderLive.Index do
  use ExmeraldaWeb, :live_view
  import ExmeraldaWeb.Admin.Helper
  alias Exmeralda.LLM.Providers

  @impl true
  def handle_params(params, _url, socket) do
    {:ok, {providers, meta}} = Providers.list_providers(params)

    socket =
      socket
      |> assign(:page_title, gettext("Providers"))
      |> assign(:providers, providers)
      |> assign(:meta, meta)

    {:noreply, socket}
  end

  @impl true
  def handle_event("delete", %{"provider-id" => provider_id}, socket) do
    {:noreply,
     case Providers.delete_provider(provider_id) do
       :ok ->
         socket
         |> put_flash(:info, gettext("Provider successfully deleted."))
         |> push_patch(to: ~p"/admin/providers")

       {:error, :provider_used} ->
         socket
         |> put_flash(:error, gettext("Provider is used and cannot be deleted."))
         |> push_patch(to: ~p"/admin/providers")
     end}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.admin_nav_layout user={@current_user} current_path={@current_path}>
      <.breadcrumbs>
        <:items
          title={gettext("Providers")}
          href={~p"/admin/providers"}
          icon_name="hero-building-storefront-micro"
        />
      </.breadcrumbs>

      <.header title={gettext("Providers")}>
        <:actions>
          <a href={~p"/admin/providers/new"} class="btn btn-primary">
            <.icon name="hero-plus" />{gettext("Add")}
          </a>
        </:actions>
      </.header>

      <Flop.Phoenix.table
        items={@providers}
        meta={@meta}
        path={~p"/admin/providers"}
        opts={[table_attrs: [class: "table"]]}
      >
        <:col :let={provider} label={gettext("ID")} field={:id}>
          {provider.id}
        </:col>
        <:col :let={provider} label={gettext("Type")} field={:type}>
          {provider.type}
        </:col>
        <:col :let={provider} label={gettext("Name")} field={:name}>
          {provider.name}
        </:col>
        <:col :let={provider} label={gettext("Config")} field={:config}>
          <pre>{Jason.encode!(provider.config)}</pre>
        </:col>
        <:col :let={provider} label={gettext("Created At")} field={:inserted_at}>
          {datetime(provider.inserted_at)}
        </:col>
        <:col :let={provider} label="Actions">
          <.button
            phx-click="delete"
            phx-value-provider-id={provider.id}
            class={"btn btn-error e2e-delete-provider-#{provider.id}"}
            disabled={!provider.deletable}
          >
            {gettext("Delete")}
          </.button>
        </:col>
      </Flop.Phoenix.table>

      <.pagination meta={@meta} path={~p"/admin/providers"} />
    </.admin_nav_layout>
    """
  end
end
