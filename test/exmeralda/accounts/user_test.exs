defmodule Exmeralda.Accounts.UserTest do
  use Exmeralda.DataCase, async: true

  alias Exmeralda.Accounts.User

  describe "changeset/1" do
    test "required fields" do
      User.changeset(%User{}, %{})
      |> assert_required_error_on(:name)
      |> assert_required_error_on(:email)
      |> assert_required_error_on(:github_id)
      |> assert_required_error_on(:github_profile)
      |> assert_required_error_on(:avatar_url)
    end
  end
end
