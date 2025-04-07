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
  def get_user(id), do: Repo.get(User, id)

  @doc """
  Inserts or updates users, depending on the github_id.
  Leaves the email in place, since the user can update the email
  manually.
  """
  def upsert_user(params) do
    %User{}
    |> User.changeset(params)
    |> Repo.insert(
      on_conflict: {:replace_all_except, [:id, :email, :inserted_at, :terms_accepted_at]},
      conflict_target: :github_id,
      returning: true
    )
  end

  def change_user_email(user, params \\ %{}) do
    User.email_changeset(user, params)
  end

  def update_user_email(user, params) do
    change_user_email(user, params)
    |> Repo.update()
  end

  def accept_terms!(user) do
    user |> User.accept_terms_changeset() |> Repo.update!()
  end

  def delete_user(user) do
    Repo.delete(user)
  end
end
