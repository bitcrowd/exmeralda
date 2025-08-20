defmodule ExmeraldaWeb.ChatLive.Index do
  use ExmeraldaWeb, :live_view

  alias Exmeralda.Chats
  alias ExmeraldaWeb.ChatLive.{Chat, StartChat}
  alias ExmeraldaWeb.ChatLive.Ingestions.Index, as: ListIngestions
  alias Phoenix.PubSub

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      PubSub.subscribe(Exmeralda.PubSub, "user-#{socket.assigns.current_user.id}")
      PubSub.subscribe(Exmeralda.PubSub, "ingestions")
    end

    {:ok, stream(socket, :sessions, Chats.list_sessions(socket.assigns.current_user), at: -1)}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :show, %{"id" => id}) do
    session = Chats.get_session!(socket.assigns.current_user.id, id)

    socket
    |> assign(:page_title, session.title)
    |> assign(:current_session, session)
  end

  defp apply_action(socket, :new, params) do
    socket
    |> assign(:page_title, gettext("New Session"))
    |> assign(:current_session, nil)
    |> assign(:params, params)
  end

  defp apply_action(socket, :list_ingestions, _params) do
    socket
    |> assign(:page_title, gettext("Current Ingestions"))
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

  def handle_info({:ingestion_created, ingestion}, socket) do
    send_update(ListIngestions,
      id: "list_ingestions",
      event: :ingestion_created,
      ingestion: ingestion
    )

    {:noreply, socket}
  end

  def handle_info({:ingestion_state_updated, ingestion}, socket) do
    send_update(ListIngestions,
      id: "list_ingestions",
      event: :ingestion_state_updated,
      ingestion: ingestion
    )

    {:noreply, socket}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    session =
      socket.assigns.current_user.id
      |> Chats.get_session!(id)
      # We want to preserve sessions and messages to be able to produce meaningful
      # statistics on the quality of the answers. Instead of deleting the session,
      # we just nilify the user_id.
      |> Chats.unlink_user_from_session!()

    socket = stream_delete(socket, :sessions, session)

    if socket.assigns.current_session && session.id == socket.assigns.current_session.id do
      {:noreply, push_navigate(socket, to: ~p"/chat/start")}
    else
      {:noreply, socket}
    end
  end

  def session_title(assigns) do
    ~H"""
    {@session.title}
    """
  end

  @active_chat_class "bg-base-300"
  def mark_active_chat(js \\ %JS{}) do
    js |> no_active_chat() |> JS.add_class(@active_chat_class)
  end

  def no_active_chat(js \\ %JS{}) do
    JS.remove_class(js, @active_chat_class, to: "#chats li")
  end

  def active_chat_class, do: @active_chat_class
end
