defmodule Exmeralda.Factory do
  use ExMachina.Ecto, repo: Exmeralda.Repo

  def chat_session_factory do
    %Exmeralda.Chats.Session{
      user: build(:user)
    }
  end

  def user_factory do
    %Exmeralda.Accounts.User{
      name: "Evil Rick",
      email: "rick@bitcrowd.io",
      github_id: sequence(:gitub_id, &"#{&1}"),
      avatar_url: "https://via.placeholder.com/150",
      github_profile: "http://github.com/bitcrowd"
    }
  end
end
