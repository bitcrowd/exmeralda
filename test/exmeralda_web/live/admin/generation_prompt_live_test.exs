defmodule ExmeraldaWeb.Admin.GenerationPromptLiveTest do
  use ExmeraldaWeb.ConnCase
  import Phoenix.LiveViewTest

  defp insert_user(_) do
    %{user: insert(:user)}
  end

  defp insert_generation_prompt(_) do
    %{generation_prompt: insert(:generation_prompt)}
  end

  describe "authentication" do
    for route <- ["/admin/generation_prompts", "/admin/generation_prompts/new"] do
      test "is required for #{route}", %{conn: conn} do
        assert {:error,
                {:redirect, %{flash: %{"error" => "You must log in to access this page."}}}} =
                 live(conn, unquote(route))
      end
    end
  end

  describe "Index" do
    setup [:insert_user, :insert_generation_prompt]

    test "lists all generation_prompts", %{
      conn: conn,
      user: user,
      generation_prompt: generation_prompt
    } do
      conn = log_in_user(conn, user)

      {:ok, _index_live, html} = live(conn, ~p"/admin/generation_prompts")

      assert html =~ "Generation Prompts"
      assert html =~ generation_prompt.prompt
    end

    test "saves new generation_prompt", %{conn: conn, user: user} do
      conn = log_in_user(conn, user)

      {:ok, new_live, _html} = live(conn, ~p"/admin/generation_prompts/new")

      assert new_live
             |> form("#generation_prompt-form", generation_prompt: %{})
             |> render_submit() =~ "can&#39;t be blank"

      assert {:error, {:live_redirect, %{to: "/admin/generation_prompts"}}} =
               new_live
               |> form("#generation_prompt-form",
                 generation_prompt: %{prompt: "You are a duck and you speak *only* like a duck."}
               )
               |> render_submit()
    end

    test "deletes generation_prompt in listing", %{
      conn: conn,
      user: user,
      generation_prompt: generation_prompt
    } do
      conn = log_in_user(conn, user)

      {:ok, index_live, _html} = live(conn, ~p"/admin/generation_prompts")

      assert index_live
             |> element(".e2e-delete-generation-prompt-#{generation_prompt.id}", "Delete")
             |> render_click()

      html = render(index_live)
      refute html =~ generation_prompt.prompt
    end
  end
end
