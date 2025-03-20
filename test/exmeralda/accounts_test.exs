defmodule Exmeralda.AccountsTest do
  use Exmeralda.DataCase

  alias Exmeralda.Accounts
  alias Exmeralda.Accounts.User
  alias Exmeralda.Repo

  def insert_user(_) do
    %{user: insert(:user)}
  end

  describe "get_user/1" do
    setup [:insert_user]

    test "get_user/1 returns the user with given id", %{user: user} do
      assert Accounts.get_user(user.id) == user
    end

    test "get_user/1 returns nil when the id does not exist" do
      refute Accounts.get_user(Ecto.UUID.generate())
    end
  end

  describe "upsert_user/1" do
    setup do
      %{user: insert(:user)}
    end

    test "with invalid data returns a changeset" do
      {:error, %Ecto.Changeset{}} = Accounts.upsert_user(%{})
    end

    test "inserts with valid data and a new github_id", %{user: user} do
      attrs = params_for(:user, github_id: "666")

      assert {:ok, new_user} = Accounts.upsert_user(attrs)

      user_ids = Repo.all(User) |> Enum.map(& &1.id)

      assert user.id in user_ids
      assert new_user.id in user_ids
    end

    test "updates with valid data and a existing github_id", %{user: user} do
      attrs = params_for(:user, github_id: user.github_id, name: "Funky", email: "foo@bar.baz123")

      assert {:ok, new_user} = Accounts.upsert_user(attrs)

      assert user.id == new_user.id
      assert new_user.name == "Funky"
      assert new_user.email == user.email
    end
  end
end
