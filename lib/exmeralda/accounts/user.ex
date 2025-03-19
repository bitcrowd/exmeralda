defmodule Exmeralda.Accounts.User do
  use Exmeralda.Schema

  schema "users" do
    field :name, :string
    field :email, :string
    field :github_id, :string
    field :github_profile, :string
    field :avatar_url, :string

    timestamps()
  end

  @doc false
  def changeset(user, attrs) do
    user
    |> cast(attrs, [:name, :email, :github_id, :avatar_url, :github_profile])
    |> validate_required([:name, :email, :github_id, :avatar_url, :github_profile])
    |> validate_email(:email)
    |> validate_url(:avatar_url)
  end
end
