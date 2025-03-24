defmodule ExmeraldaWeb.UserSettingsLiveTest do
  use ExmeraldaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  def insert_user(_) do
    %{user: insert(:user)}
  end

  describe "Settings page" do
    setup :insert_user

    test "renders settings page", %{conn: conn, user: user} do
      {:ok, _lv, html} =
        conn
        |> log_in_user(user)
        |> live(~p"/auth/settings")

      assert html =~ "E-Mail"
    end

    test "redirects if user is not logged in", %{conn: conn} do
      assert {:error, redirect} = live(conn, ~p"/auth/settings")

      assert {:redirect, %{to: path, flash: flash}} = redirect
      assert path == ~p"/"
      assert %{"error" => "You must log in to access this page."} = flash
    end

    test "updates the user email", %{conn: conn, user: user} do
      {:ok, lv, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/auth/settings")

      lv
      |> form("#email_form", %{
        "email" => "foo@bar.com"
      })
      |> render_submit()

      {:ok, _lv, html} =
        conn
        |> log_in_user(user)
        |> live(~p"/auth/settings")

      assert html =~ "foo@bar.com"
    end

    test "renders errors with invalid data (phx-change)", %{conn: conn, user: user} do
      {:ok, lv, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/auth/settings")

      result =
        lv
        |> element("#email_form")
        |> render_change(%{
          "action" => "update_email",
          "email" => "foo"
        })

      assert result =~ "has invalid format"
    end

    test "renders errors with invalid data (phx-submit)", %{conn: conn, user: user} do
      {:ok, lv, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/auth/settings")

      result =
        lv
        |> form("#email_form", %{
          "email" => "invalid"
        })
        |> render_submit()

      assert result =~ "E-Mail"
      assert result =~ "has invalid format"
    end
  end
end
