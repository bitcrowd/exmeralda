defmodule ExmeraldaWeb.LibraryLive.Index do
  use ExmeraldaWeb, :live_view

  alias Exmeralda.Topics

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :form, Topics.new_library_changeset() |> to_form())}
  end

  @impl true
  def handle_event("validate", %{"library" => params}, socket) do
    socket =
      assign(
        socket,
        :form,
        Topics.new_library_changeset(params) |> Map.put(:action, :validate) |> to_form()
      )

    {:noreply, socket}
  end

  def handle_event("save", %{"library" => params}, socket) do
    socket =
      case Topics.create_library(params) do
        {:ok, _} ->
          socket
          |> put_flash(
            :info,
            gettext(
              "Your new library will be available in a few minutes! Thanks for participating."
            )
          )
          |> push_navigate(to: ~p"/chat/start")

        {:error, changeset} ->
          assign(socket, :form, changeset |> to_form())
      end

    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.navbar_layout user={@current_user}>
      <.hero_layout inside_navbar>
        <div class="flex flex-col lg:flex-row-reverse">
          <img src={~p"/images/logo.png"} class="rounded-lg" />
          <div class="max-w-md p-7">
            <h1 class="text-5xl font-bold">{gettext("What next?")}</h1>
            <p class="py-6">
              {gettext("Choose a library you want me to look at.")}
            </p>
            <.simple_form for={@form} id="start-form" phx-submit="save" phx-change="validate">
              <.input
                field={@form[:name]}
                label={gettext("Name")}
                autocomplete="off"
                placeholder="ecto"
              />
              <.input field={@form[:version]} label={gettext("Version")} placeholder="3.12.5" />
              <:actions>
                <.button id="submit" class="btn-primary" phx-disable-with="Saving...">
                  {gettext("Have a look, please!")}
                </.button>
              </:actions>
            </.simple_form>
          </div>
        </div>
      </.hero_layout>
    </.navbar_layout>
    """
  end
end
