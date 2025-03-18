defmodule ExmeraldaWeb.ChatLive.Chat do
  use ExmeraldaWeb, :live_component

  @impl true
  def render(assigns) do
    ~H"""
    <div class="p-4">
      <h1>{@session.id}</h1>
      <div class="chat chat-start">
        <div class="chat-bubble">
          It's over Anakin, <br /> I have the high ground.
        </div>
      </div>
      <div class="chat chat-end">
        <div class="chat-bubble">You underestimate my power!</div>
      </div>
    </div>
    """
  end
end
