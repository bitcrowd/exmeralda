defmodule Exmeralda.Chats do
  @moduledoc """
  The Chats context.
  """

  import Ecto.Query, warn: false
  alias Exmeralda.Repo

  alias Exmeralda.Chats.Session

  @doc """
  Returns the list of chat_sessions.
  """
  def list_sessions do
    Repo.all(from s in Session, order_by: [desc: s.inserted_at])
  end

  @doc """
  Gets a single session.
  """
  def get_session!(id), do: Repo.get!(Session, id)

  @doc """
  Starts a session.
  """
  def start_session(attrs \\ %{}) do
    %Session{}
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
