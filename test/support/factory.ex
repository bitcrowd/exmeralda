defmodule Exmeralda.Factory do
  use ExMachina.Ecto, repo: Exmeralda.Repo

  def chat_session_factory do
    %Exmeralda.Chat.Session{}
  end
end
