defmodule Exmeralda.Factory do
  use ExMachina.Ecto, repo: Exmeralda.Repo

  def chat_session_factory do
    %Exmeralda.Chats.Session{
      title: "A fancy session",
      user: build(:user),
      ingestion: build(:ingestion)
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
      github_profile: "http://github.com/bitcrowd",
      terms_accepted_at: DateTime.utc_now()
    }
  end

  def library_factory do
    %Exmeralda.Topics.Library{
      name: sequence(:library_name, &"library-#{&1}"),
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

  def ingestion_factory do
    %Exmeralda.Topics.Ingestion{
      state: :queued,
      library: build(:library)
    }
  end

  def chunk_factory do
    %Exmeralda.Topics.Chunk{
      library: build(:library),
      content: "I am a message",
      embedding: Enum.map(1..768, fn _ -> :rand.uniform() end),
      source: "file.ex",
      type: :code
    }
  end

  def chat_source_factory do
    %Exmeralda.Chats.Source{
      chunk: build(:chunk),
      message: build(:message)
    }
  end
end
