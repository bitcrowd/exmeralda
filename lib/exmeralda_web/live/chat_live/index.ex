defmodule ExmeraldaWeb.ChatLive.Index do
  use ExmeraldaWeb, :live_view

  alias Exmeralda.Chats

  @impl true
  def mount(_params, _session, socket) do
    {:ok, stream(socket, :sessions, Chats.list_sessions(), at: -1)}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :show, %{"id" => id}) do
    socket
    |> assign(:page_title, id)
    |> assign(:session, Chats.get_session!(id))
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "New Session")
  end

  @impl true
  def handle_info({ExmeraldaWeb.ChatLive.StartChat, {:start, session}}, socket) do
    {:noreply, stream_insert(socket, :sessions, session, at: 0)}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    session = Chats.get_session!(id)
    {:ok, _} = Chats.delete_session(session)

    {:noreply, stream_delete(socket, :sessions, session)}
  end

  def session_title(assigns) do
    ~H"""
    {@session.id}
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
