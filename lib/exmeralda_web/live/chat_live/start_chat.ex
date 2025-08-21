defmodule ExmeraldaWeb.ChatLive.StartChat do
  use ExmeraldaWeb, :live_component
  import ExmeraldaWeb.Shared.Helper
  alias Exmeralda.Topics
  alias Exmeralda.Chats

  @impl true
  def render(assigns) do
    ~H"""
    <div class="hero h-full">
      <div class="hero-content flex-col lg:flex-row-reverse gap-16">
        <img
          src={~p"/images/logo-exmeralda.svg"}
          width="523"
          height="516"
          alt="Exmeralda logo, with stylised circuit board tracks surrounding a central node"
          class="max-w-xs"
        />
        <div class="max-w-md p-7">
          <h1 class="text-5xl font-bold mb-4">Ask Exmeralda</h1>
          <p>
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
              <span :if={!@selected_library}>{gettext("Select a library…")}</span>

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
    %{params: params} = assigns
    libraries = Topics.last_libraries()

    {:ok,
     socket
     |> assign(assigns)
     |> assign_new(:libraries, fn -> libraries end)
     |> assign_new(:selected_library, fn -> find_library(params, libraries) end)
     |> assign_new(:form, fn ->
       to_form(Chats.new_session_changeset())
     end)}
  end

  defp find_library(%{"selected_library" => selected_library}, libraries) do
    Enum.find(libraries, &(&1.id == selected_library))
  end

  defp find_library(_, _), do: nil

  @impl true
  def handle_event("start", %{"session" => session_params}, socket) do
    %{selected_library: library} = socket.assigns

    case Topics.active_ingestion(library.id) do
      nil ->
        {:noreply,
         socket
         |> put_flash(
           :error,
           gettext("This library cannot be used anymore! Try adding it again.")
         )
         |> push_navigate(to: ~p"/chat/start")}

      active_ingestion ->
        do_start_session(socket, session_params, active_ingestion)
    end
  end

  @impl true
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

  defp do_start_session(socket, session_params, active_ingestion) do
    %{user: user, selected_library: library} = socket.assigns

    params =
      Map.merge(session_params, %{
        "ingestion_id" => active_ingestion.id,
        "library_id" => active_ingestion.library_id
      })

    case Chats.start_session(user, params) do
      {:ok, session} ->
        notify_parent({:start, Map.put(session, :library, library)})
        {:noreply, push_patch(socket, to: ~p"/chat/#{session.id}")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end
end
