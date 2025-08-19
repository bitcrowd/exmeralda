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
  def update(%{session_update: {:sources, message_id}}, socket) do
    message = Chats.get_message!(message_id)

    {:ok, stream_insert(socket, :messages, message)}
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
  def handle_event("upvote", %{"value" => message_id}, socket) do
    handle_vote(socket, message_id, :upvote)
  end

  def handle_event("downvote", %{"value" => message_id}, socket) do
    handle_vote(socket, message_id, :downvote)
  end

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

  defp handle_vote(socket, message_id, type) do
    %{session: session} = socket.assigns.session

    Chats.upsert_reaction!(message_id, session, type)
    message = Chats.get_message!(message_id)
    {:noreply, stream_insert(socket, :messages, message, update_only: true)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="h-[calc(100vh-4rem)] flex flex-col">
      <div
        class="grow p-4 overflow-y-auto flex flex-col gap-4"
        phx-update="stream"
        id={"messages-#{@session.id}"}
      >
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
            <details
              :if={message.role == :assistant && message.sources |> Enum.any?()}
              class="mt-3 mb-1"
            >
              <summary>{gettext("Sources")}</summary>
              <ul class="menu">
                <li
                  :for={{source, chunks} <- message.source_chunks |> Enum.group_by(& &1.source)}
                  class="mb-0"
                >
                  <% type = List.first(chunks).type %>
                  <a
                    :if={type == :docs}
                    href={"https://hexdocs.pm/#{@session.library.name}/#{@session.library.version}/#{source}"}
                    target="blank"
                    rel="noopener noreferrer"
                  >
                    <.icon name="hero-book-open" />
                    {source}
                  </a>

                  <a
                    :if={type == :code}
                    href={"https://preview.hex.pm/preview/#{@session.library.name}/#{@session.library.version}/show/#{source}"}
                    target="blank"
                    rel="noopener noreferrer"
                  >
                    <.icon name="hero-code-bracket" />
                    {source}
                  </a>
                </li>
              </ul>
            </details>
          </div>
          <div class="chat-footer p-2 gap-4">
            <div :if={message.role == :assistant}>
              <%!-- TODO: show different buttons and action if user removes the vote --%>
              <.button
                id="upvote"
                class={[
                  "btn btn-xs btn-soft btn-circle btn-success btn-outline",
                  message.reaction && message.reaction.type == :upvote && "btn-active"
                ]}
                phx-click="upvote"
                value={message.id}
                phx-target={@myself}
              >
                <.icon name="hero-hand-thumb-up" />
              </.button>
              <.button
                id="downvote"
                class={[
                  "btn btn-xs btn-soft btn-circle btn-error",
                  message.reaction && message.reaction.type == :downvote && "btn-active"
                ]}
                phx-click="downvote"
                value={message.id}
                phx-target={@myself}
              >
                <.icon name="hero-hand-thumb-down" />
              </.button>
            </div>
            <span :if={message.incomplete} class="opacity-50 loading loading-dots loading-xs"></span>
          </div>
        </div>
      </div>
      <.form for={@form} phx-target={@myself} phx-submit="send" class="flex shrink-0">
        <input type="hidden" name={@form[:index].name} value={@index + 1} />
        <input
          class="input grow w-auto py-4 h-auto rounded-none border-x-0 border-b-0 text-lg border-t-2 dark:border-gray-700"
          name={@form[:content].name}
          placeholder={gettext("What can I help you with?")}
        />
        <.button
          id="submit"
          class="btn-primary h-auto rounded-none text-lg"
          phx-disable-with="Asking…"
        >
          Ask
        </.button>
      </.form>
    </div>
    """
  end

  def message_class(:user), do: "chat chat-end"
  def message_class(:assistant), do: "chat chat-start"

  def message_content_class(:user), do: "chat-bubble bg-violet-100 dark:bg-violet-900"
  def message_content_class(:assistant), do: "chat-bubble bg-base-200 dark:bg-base-300"

  def message_role(:user), do: gettext("You")
  def message_role(:assistant), do: gettext("Exmeralda")
end
