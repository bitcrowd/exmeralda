defmodule ExmeraldaWeb.ChatLive.Chat do
  use ExmeraldaWeb, :live_component

  alias Exmeralda.Chats

  @impl true
  def mount(socket) do
    {:ok,
     socket
     |> stream_configure(:messages, dom_id: &"message-#{&1.id}")
     |> assign(:form, Chats.new_message_changeset() |> to_form())}
  end

  @impl true
  def update(%{session_update: {:message_delta, message_id, delta}}, socket) do
    messages = socket.assigns.incomplete_messages

    updated_message =
      messages
      |> Map.get_lazy(message_id, fn -> Chats.get_message!(message_id) end)
      |> Map.update!(:content, fn content -> content <> (delta || "") end)

    {:ok,
     socket
     |> assign(:incomplete_messages, Map.put(messages, message_id, updated_message))
     |> stream_insert(:messages, updated_message)}
  end

  def update(%{session_update: {:message_completed, %{id: message_id} = message}}, socket) do
    {:ok,
     assign(
       socket,
       :incomplete_messages,
       Map.delete(socket.assigns.incomplete_messages, message_id)
     )
     |> assign(:index, socket.assigns.index + 1)
     |> stream_insert(:messages, message)}
  end

  def update(assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> stream(:messages, assigns.session.messages)
     |> assign_new(:incomplete_messages, fn ->
       Enum.filter(assigns.session.messages, & &1.incomplete) |> Map.new(&{&1.id, &1})
     end)
     |> assign(:index, assigns.session.messages |> List.last() |> Map.get(:index))}
  end

  @impl true
  def handle_event("send", %{"message" => message_params}, socket) do
    socket.assigns.session
    |> Chats.continue_session(message_params)
    |> case do
      {:ok, [message, assistant_message]} ->
        {:noreply,
         socket
         |> assign(:index, socket.assigns.index + 1)
         |> stream_insert(:messages, message)
         |> stream_insert(:messages, assistant_message)
         |> assign(:form, Chats.new_message_changeset() |> to_form())
         |> assign(
           :incomplete_messages,
           Map.put(socket.assigns.incomplete_messages, assistant_message.id, assistant_message)
         )}

      {:error, changeset} ->
        {:noreply,
         socket
         |> assign(:form, changeset |> to_form())}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="h-[calc(100vh-4rem)] overflow-scroll">
      <div class="p-4 mb-10" phx-update="stream" id={"messages-#{@session.id}"}>
        <div :for={{id, message} <- @streams.messages} class={message_class(message.role)} id={id}>
          <div :if={message.role == :user} class="chat-image avatar">
            <div class="w-10 rounded-full">
              <img alt={@user.name} src={@user.avatar_url} />
            </div>
          </div>
          <div class="chat-header">
            {message_role(message.role)}
          </div>
          <div class={[
            "chat chat-container px-5",
            message_content_class(message.role)
          ]}>
            {message.content |> MDEx.to_html!() |> raw()}
          </div>
          <div class="chat-footer opacity-50">
            <span :if={message.incomplete} class="loading loading-dots loading-xs"></span>
          </div>
        </div>
      </div>
      <div class="flex justify-center fixed bottom-1 w-full">
        <.form for={@form} phx-target={@myself} phx-submit="send" class="join">
          <input type="hidden" name={@form[:index].name} value={@index + 1} />
          <input
            class="input join-item w-64 sm:w-96"
            name={@form[:content].name}
            placeholder={gettext("What can I help you with?")}
          />
          <.button id="submit" class="btn-primary join-item" phx-disable-with="Asking...">
            Go
          </.button>
        </.form>
      </div>
    </div>
    """
  end

  def message_class(:user), do: "chat chat-start"
  def message_class(:assistant), do: "chat chat-end"

  def message_content_class(:user), do: "chat-bubble bg-base-300"
  def message_content_class(:assistant), do: "chat-bubble bg-base-200"

  def message_role(:user), do: gettext("You")
  def message_role(:assistant), do: gettext("Assistant")
end
