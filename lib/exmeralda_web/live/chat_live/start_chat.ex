defmodule ExmeraldaWeb.ChatLive.StartChat do
  use ExmeraldaWeb, :live_component

  alias Exmeralda.Topics
  alias Exmeralda.Chats

  @impl true
  def render(assigns) do
    ~H"""
    <div class="hero">
      <div class="hero-content flex-col lg:flex-row-reverse">
        <img
          src={~p"/images/logo-exmeralda.png"}
          width="523"
          height="516"
          alt="Exmeralda logo, with stylised circuit board tracks surrounding a central node"
          class="max-w-sm rounded-lg"
        />
        <div class="max-w-md p-7">
          <h1 class="text-5xl font-bold">Just ask Exmeralda</h1>
          <p class="py-6">
            {gettext("Choose a library, and ask me anything about it.")}
          </p>
          <.simple_form
            for={@form}
            id="start-form"
            phx-target={@myself}
            phx-submit="start"
            phx-change="validate"
          >
            <input
              type="hidden"
              name={@form[:library_id].name}
              value={@selected_library && @selected_library.id}
            />
            <.dropdown>
              <.library :if={@selected_library} library={@selected_library} />
              <span :if={!@selected_library}>{gettext("Select a library...")}</span>

              <:menu>
                <.search_input phx-debounce="200" phx-change="search" phx-target={@myself} name="q" />
                <div :if={Enum.empty?(@libraries)} class="text-center m-2">
                  {gettext("No results")}
                </div>
                <ul class="menu w-full">
                  <li :for={library <- @libraries}>
                    <a
                      phx-click={JS.push("select") |> JS.focus(to: "#close")}
                      phx-value-id={library.id}
                      phx-target={@myself}
                    >
                      <.library library={library} />
                    </a>
                  </li>
                </ul>
                <div class="text-sm p-4">
                  {gettext("Missing one?")}
                  <.link class="link" navigate={~p"/library/new"}>{gettext("Add it here")}</.link>
                </div>
              </:menu>
            </.dropdown>
            <div id="close" tabindex="0" />
            <.input field={@form[:prompt]} placeholder={gettext("What can I help you with?")} />
            <:actions>
              <.button
                id="submit"
                class="btn-primary"
                phx-disable-with="Saving..."
                disabled={!@selected_library}
              >
                Start
              </.button>
            </:actions>
          </.simple_form>
        </div>
      </div>
    </div>
    """
  end

  @impl true
  def update(assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign_new(:libraries, fn ->
       Topics.last_libraries()
     end)
     |> assign_new(:selected_library, fn -> nil end)
     |> assign_new(:form, fn ->
       to_form(Chats.new_session_changeset())
     end)}
  end

  @impl true
  def handle_event("start", %{"session" => session_params}, socket) do
    case Chats.start_session(socket.assigns.user, session_params) do
      {:ok, session} ->
        notify_parent({:start, Map.put(session, :library, socket.assigns.selected_library)})

        {:noreply,
         socket
         |> push_patch(to: ~p"/chat/#{session.id}")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  def handle_event("validate", %{"session" => session_params}, socket) do
    {:noreply,
     socket
     |> assign(
       :form,
       to_form(Chats.new_session_changeset(session_params))
     )}
  end

  @impl true
  def handle_event("search", params, socket) do
    libraries =
      if params["q"] == "" do
        Topics.last_libraries()
      else
        Topics.search_libraries(params["q"])
      end

    socket = assign(socket, :libraries, libraries)

    {:noreply, socket}
  end

  @impl true
  def handle_event("select", params, socket) do
    socket = assign(socket, :selected_library, Topics.get_library!(params["id"]))

    {:noreply, socket}
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})

  defp library(assigns) do
    ~H"""
    {@library.name}
    <div class="badge badge-primary">{@library.version}</div>
    """
  end
end
