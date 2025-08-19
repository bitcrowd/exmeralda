defmodule ExmeraldaWeb.LibraryLive.Index do
  use ExmeraldaWeb, :live_view

  alias Exmeralda.Topics

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:form, Topics.new_library_changeset() |> to_form())
     |> assign_async(:hex, fn ->
       Topics.Hex.list()
       |> case do
         {:ok, hex} ->
           hex =
             hex |> Map.get(:packages) |> Map.new(&{&1[:name], &1[:versions] |> Enum.reverse()})

           {:ok, %{hex: hex}}

         error ->
           error
       end
     end)}
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
    %{current_user: user} = socket.assigns

    socket =
      case Topics.create_library(user, params) do
        {:ok, _} ->
          socket
          |> put_flash(
            :info,
            gettext(
              "Your new library will be available in a few minutes! Thanks for participating."
            )
          )
          |> push_navigate(to: ~p"/ingestions")

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
          <img
            src={~p"/images/logo-exmeralda.svg"}
            width="523"
            height="516"
            alt="Exmeralda logo, with stylised circuit board tracks surrounding a central node"
            class="rounded-lg"
          />
          <div class="max-w-md p-7">
            <h1 class="text-5xl font-bold">{gettext("What next?")}</h1>
            <p class="py-6">
              {gettext("Choose a library you want me to look at.")}
            </p>
            <.simple_form for={@form} id="start-form" phx-submit="save" phx-change="validate">
              <.async_result :let={hex} assign={@hex}>
                <:loading>
                  <span class="loading loading-spinner loading-md"></span>
                  {gettext("Loading list from hex.pm")}
                </:loading>
                <:failed :let={_failure}>
                  {gettext("Loading from hex.pm failed. Try again later.")}
                </:failed>
                <.input field={@form[:name]} label={gettext("Name")} autocomplete="off" />
                <.input
                  field={@form[:version]}
                  label={gettext("Version")}
                  disabled={!Map.has_key?(hex, @form[:name].value)}
                  type="select"
                  options={hex |> Map.get(@form[:name].value, [])}
                />
              </.async_result>
              <:actions>
                <.button
                  id="submit"
                  disabled={!@hex.ok?}
                  class="btn-primary"
                  phx-disable-with="Saving..."
                >
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
