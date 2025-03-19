defmodule ExmeraldaWeb.ChatLive.StartChat do
  use ExmeraldaWeb, :live_component

  alias Exmeralda.Chat

  @impl true
  def render(assigns) do
    ~H"""
    <div class="hero">
      <div class="hero-content flex-col lg:flex-row-reverse">
        <img src={~p"/images/logo.jpeg"} class="max-w-sm rounded-lg shadow-2xl" />
        <div class="max-w-md">
          <h1 class="text-5xl font-bold">Just ask Exmeralda</h1>
          <p class="py-6">
            Provident cupiditate voluptatem et in. Quaerat fugiat ut assumenda excepturi exercitationem
            quasi. In deleniti eaque aut repudiandae et a id nisi.
          </p>
          <.simple_form for={@form} id="start-form" phx-target={@myself} phx-submit="start">
            <:actions>
              <.button class="btn-primary" phx-disable-with="Saving...">Start</.button>
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
     |> assign_new(:form, fn ->
       to_form(Chat.session_changeset())
     end)}
  end

  # @impl true
  # def handle_event("validate", %{"session" => session_params}, socket) do
  #   changeset = Chat.session_changeset(session_params)
  #   {:noreply, assign(socket, form: to_form(changeset, action: :validate))}
  # end

  @impl true
  def handle_event("start", _, socket) do
    case Chat.start_session(%{}) do
      {:ok, session} ->
        notify_parent({:start, session})

        {:noreply,
         socket
         |> push_patch(to: ~p"/chats/#{session.id}")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})
end
