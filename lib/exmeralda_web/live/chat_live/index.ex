defmodule ExmeraldaWeb.ChatLive.Index do
  use ExmeraldaWeb, :live_view

  alias Exmeralda.Chats
  alias ExmeraldaWeb.ChatLive.{Chat, StartChat}
  alias Phoenix.PubSub

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket),
      do: PubSub.subscribe(Exmeralda.PubSub, "user-#{socket.assigns.current_user.id}")

    {:ok, stream(socket, :sessions, Chats.list_sessions(socket.assigns.current_user), at: -1)}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :show, %{"id" => id}) do
    session = Chats.get_session!(socket.assigns.current_user, id)

    socket
    |> assign(:page_title, session.title)
    |> assign(:current_session, session)
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, gettext("New Session"))
    |> assign(:current_session, nil)
  end

  @impl true
  def handle_info({ExmeraldaWeb.ChatLive.StartChat, {:start, session}}, socket) do
    {:noreply, stream_insert(socket, :sessions, session, at: 0)}
  end

  def handle_info({:session_update, session_id, data}, socket) do
    current_session = socket.assigns.current_session

    if current_session && current_session.id == session_id do
      send_update(Chat, id: "chat", session_update: data)
    end

    {:noreply, socket}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    session = Chats.get_session!(socket.assigns.current_user, id)
    {:ok, _} = Chats.delete_session(session)

    socket = stream_delete(socket, :sessions, session)

    if session.id == socket.assigns.current_session.id do
      {:noreply, push_navigate(socket, to: ~p"/chat/start")}
    else
      {:noreply, socket}
    end
  end

  def session_title(assigns) do
    ~H"""
    {@session.title}
    <div class="badge badge-info">{@session.library.name}</div>
    """
  end

  @active_chat_class "bg-primary"
  def mark_active_chat(js \\ %JS{}) do
    js |> no_active_chat() |> JS.add_class(@active_chat_class)
  end

  def no_active_chat(js \\ %JS{}) do
    JS.remove_class(js, @active_chat_class, to: "#chats li")
  end

  def active_chat_class, do: @active_chat_class
end
