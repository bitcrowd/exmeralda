defmodule Exmeralda.AccountsTest do
  use Exmeralda.DataCase

  alias Exmeralda.Accounts

  def insert_user(_) do
    %{user: insert(:user)}
  end

  describe "users" do
    setup [:insert_user]

    test "list_users/0 returns all users", %{user: user} do
      assert Accounts.list_users() == [user]
    end

    test "get_user!/1 returns the user with given id", %{user: user} do
      assert Accounts.get_user!(user.id) == user
    end
   end
end
