defmodule ExmeraldaWeb.Admin.SystemPromptLiveTest do
  use ExmeraldaWeb.ConnCase
  import Phoenix.LiveViewTest

  defp insert_user(_) do
    %{user: insert(:user)}
  end

  defp insert_system_prompt(_) do
    %{system_prompt: insert(:system_prompt, prompt: "You are an expert in testing")}
  end

  describe "authentication" do
    for route <- ["/admin/system_prompts", "/admin/system_prompts/new"] do
      test "is required for #{route}", %{conn: conn} do
        assert {:error,
                {:redirect, %{flash: %{"error" => "You must log in to access this page."}}}} =
                 live(conn, unquote(route))
      end
    end
  end

  describe "Index" do
    setup [:insert_user, :insert_system_prompt]

    test "lists all system_prompts", %{conn: conn, user: user, system_prompt: system_prompt} do
      conn = log_in_user(conn, user)

      {:ok, _index_live, html} = live(conn, ~p"/admin/system_prompts")

      assert html =~ "System Prompts"
      assert html =~ system_prompt.id
      assert html =~ system_prompt.prompt
    end

    test "shows the currently active prompt", %{
      conn: conn,
      user: user,
      system_prompt: system_prompt
    } do
      conn = log_in_user(conn, user)

      {:ok, index_live, html} = live(conn, ~p"/admin/system_prompts")

      assert html =~ "System Prompts"
      assert html =~ system_prompt.id
      assert html =~ system_prompt.prompt

      refute index_live |> has_element?(".e2e-active-badge")

      active_system_prompt =
        insert(:system_prompt, prompt: "You are skipping tests", active: true)

      {:ok, index_live, html} = live(conn, ~p"/admin/system_prompts")

      assert html =~ system_prompt.id
      assert html =~ system_prompt.prompt
      assert html =~ active_system_prompt.id
      assert html =~ active_system_prompt.prompt

      assert index_live |> has_element?(".e2e-active-badge")
    end

    test "saves new system_prompt", %{conn: conn, user: user} do
      conn = log_in_user(conn, user)

      {:ok, new_live, _html} = live(conn, ~p"/admin/system_prompts/new")

      assert new_live
             |> form("#system_prompt-form", system_prompt: %{})
             |> render_submit() =~ "can&#39;t be blank"

      assert {:error, {:live_redirect, %{to: "/admin/system_prompts"}}} =
               new_live
               |> form("#system_prompt-form",
                 system_prompt: %{prompt: "You are a duck and you speak *only* like a duck."}
               )
               |> render_submit()
    end

    test "deletes system_prompt in listing", %{
      conn: conn,
      user: user,
      system_prompt: system_prompt
    } do
      conn = log_in_user(conn, user)

      {:ok, index_live, html} = live(conn, ~p"/admin/system_prompts")
      assert html =~ system_prompt.id
      assert html =~ system_prompt.prompt

      assert index_live
             |> element(".e2e-delete-system-prompt-#{system_prompt.id}", "Delete")
             |> render_click()

      html = render(index_live)
      assert html =~ "System prompt successfully deleted"
      refute html =~ system_prompt.id
      refute html =~ system_prompt.prompt
    end

    test "activates system_prompt in listing", %{
      conn: conn,
      user: user,
      system_prompt: system_prompt
    } do
      conn = log_in_user(conn, user)

      {:ok, index_live, html} = live(conn, ~p"/admin/system_prompts")
      assert html =~ system_prompt.id
      assert html =~ system_prompt.prompt

      assert index_live
             |> element(".e2e-activate-system-prompt-#{system_prompt.id}", "Activate")
             |> render_click()

      html = render(index_live)
      assert html =~ "System prompt successfully activated"

      # disables activation button on already active system prompt
      assert index_live |> element(".e2e-activate-system-prompt-#{system_prompt.id}") |> render() =~
               "disabled"
    end
  end
end
