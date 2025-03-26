defmodule Exmeralda.Factory do
  use ExMachina.Ecto, repo: Exmeralda.Repo

  def chat_session_factory do
    %Exmeralda.Chats.Session{
      title: "A fancy session",
      user: build(:user),
      library: build(:library)
    }
  end

  def message_factory do
    %Exmeralda.Chats.Message{
      session: build(:chat_session),
      index: sequence(:gitub_id, & &1),
      content: "I am a message",
      role: :user
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

  def library_factory do
    %Exmeralda.Topics.Library{
      name: "ecto",
      version: "3.12.5",
      dependencies: [
        build(:library_dependency, name: "decimal", version_requirement: "~> 2.0"),
        build(:library_dependency, name: "jason", version_requirement: "~> 1.0", optional: true),
        build(:library_dependency, name: "telemetry", version_requirement: "~> 0.4 or ~> 1.0")
      ]
    }
  end

  def library_dependency_factory do
    %Exmeralda.Topics.Dependency{
      name: :decimal,
      version_requirement: "~> 2.0"
    }
  end

  def deps_to_model(deps) do
    deps
    |> Enum.map(fn
      {name, req} ->
        build(:library_dependency, name: name |> to_string(), version_requirement: req)

      {name, req, opts} ->
        build(:library_dependency,
          name: name |> to_string(),
          version_requirement: req,
          optional: Keyword.get(opts, :optional)
        )
    end)
  end
end
