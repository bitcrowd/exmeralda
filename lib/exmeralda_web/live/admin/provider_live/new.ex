defmodule ExmeraldaWeb.Admin.ProviderLive.New do
  use ExmeraldaWeb, :live_view
  alias Exmeralda.LLM.{Provider, Providers}

  @impl true
  def handle_params(_params, _url, socket) do
    socket =
      socket
      |> assign(:page_title, gettext("New Provider"))
      |> assign(:types, Ecto.Enum.values(Provider, :type))
      |> assign(:form, to_form(Providers.change_provider()))

    {:noreply, socket}
  end

  @impl true
  def handle_event("save", %{"provider" => provider_params}, socket) do
    {_, params} =
      Map.get_and_update!(provider_params, "config", &{&1, JSON.decode!(&1)})

    dbg(params)

    case Providers.create_provider(params) do
      {:ok, _provider} ->
        {:noreply,
         socket
         |> put_flash(:info, "Provider created successfully")
         |> push_navigate(to: ~p"/admin/providers")}

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
          title={gettext("Providers")}
          href={~p"/admin/providers"}
          icon_name="hero-building-storefront-micro"
        />
      </.breadcrumbs>

      <.header title={gettext("New Provider")} />

      <.simple_form for={@form} id="provider-form" phx-submit="save">
        <.input field={@form[:type]} type="select" label="Type" options={@types} />
        <.input field={@form[:name]} label="Name" />
        <.input
          field={@form[:config]}
          type="textarea"
          label="Config"
          value={(@form[:config].value && JSON.encode!(@form[:config].value)) || "{}"}
        />
        <:actions>
          <a href={~p"/admin/providers"} class="btn">{gettext("Cancel")}</a>
        </:actions>
        <:actions>
          <.button phx-disable-with="Saving..." class="btn-primary">{gettext("Save")}</.button>
        </:actions>
      </.simple_form>
    </.admin_nav_layout>
    """
  end
end
