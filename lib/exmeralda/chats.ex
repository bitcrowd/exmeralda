defmodule Exmeralda.Chats do
  @moduledoc """
  The Chats context.
  """

  import Ecto.Query, warn: false
  alias Exmeralda.Repo

  alias Exmeralda.Chats.Session

  @doc """
  Returns the list of chat_sessions of a user.
  """
  def list_sessions(user) do
    user.id
    |> session_scope()
    |> order_by([s], desc: s.inserted_at)
    |> Repo.all()
  end

  @doc """
  Gets a single session of a user.
  """
  def get_session!(user, id) do
    user.id
    |> session_scope()
    |> Repo.get!(id)
  end

  defp session_scope(user_id) do
    from s in Session, where: s.user_id == ^user_id
  end

  @doc """
  Starts a session.
  """
  def start_session(user, attrs \\ %{}) do
    %Session{user_id: user.id}
    |> Session.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Deletes a session.
  """
  def delete_session(%Session{} = session) do
    Repo.delete(session)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking session changes.
  """
  def session_changeset(attrs \\ %{}) do
    Session.changeset(%Session{}, attrs)
  end
end
