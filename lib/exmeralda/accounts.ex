defmodule Exmeralda.Accounts do
  @moduledoc """
  The Accounts context.
  """

  import Ecto.Query, warn: false
  alias Exmeralda.Repo

  alias Exmeralda.Accounts.User

  @doc """
  Get a single user.
  """
  def get_user!(id), do: Repo.get!(User, id)

  @doc """
  Inserts or updates users, depending on the github_id.
  Leaves the email in place, since the user can update the email
  manually.
  """
  def upsert_user(params) do
    %User{}
    |> User.changeset(params)
    |> Repo.insert(
      on_conflict: {:replace_all_except, [:id, :email, :inserted_at]},
      conflict_target: :github_id,
      returning: true
    )
  end
end
