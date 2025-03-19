defmodule Exmeralda.Factory do
  use ExMachina.Ecto, repo: Exmeralda.Repo

  def chat_session_factory do
    %Exmeralda.Chats.Session{}
  end

  def user_factory do
    %Exmeralda.Accounts.User{
      name: "Evil Rick",
      email: "rick@bitcrowd.io",
      github_id: "123",
      avatar_url: "https://via.placeholder.com/150",
      github_profile: "http://github.com/bitcrowd"
    }
  end
end
