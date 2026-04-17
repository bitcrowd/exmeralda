defmodule ExmeraldaWeb.Admin.GenerationEnvironmentLiveTest do
  use ExmeraldaWeb.ConnCase

  import Phoenix.LiveViewTest

  defp insert_user(_) do
    %{user: insert(:user)}
  end

  defp insert_generation_environment(_) do
    %{generation_environment: insert(:generation_environment)}
  end

  defp insert_current_generation_environment(_) do
    provider = insert(:provider, type: :mock)
    model_config = insert(:model_config)

    mcp =
      insert(:model_config_provider,
        id: test_model_config_provider_id(),
        provider: provider,
        model_config: model_config
      )

    gp = insert(:generation_prompt, id: test_generation_prompt_id())
    sp = insert(:system_prompt, active: true)

    env =
      insert(:generation_environment,
        model_config_provider: mcp,
        system_prompt: sp,
        generation_prompt: gp
      )

    %{generation_environment: env}
  end

  describe "authentication" do
    for route <- ["/admin/generation_environments", "/admin/generation_environments/foo"] do
      test "is required for #{route}", %{conn: conn} do
        assert {:error,
                {:redirect, %{flash: %{"error" => "You must log in to access this page."}}}} =
                 live(conn, unquote(route))
      end
    end
  end

  describe "Index" do
    setup [:insert_user, :insert_generation_environment]

    test "lists generation environments", %{
      conn: conn,
      user: user,
      generation_environment: generation_environment
    } do
      conn = log_in_user(conn, user)

      {:ok, _view, html} = live(conn, ~p"/admin/generation_environments")

      assert html =~ "Generation Environments"
      assert html =~ generation_environment.id
      assert html =~ generation_environment.model_config_provider.name
      refute html =~ "Created At"
    end

    test "does not show an active badge for non-current generation environments", %{
      conn: conn,
      user: user
    } do
      conn = log_in_user(conn, user)

      {:ok, view, _html} = live(conn, ~p"/admin/generation_environments")

      refute has_element?(view, ".e2e-active-badge")
    end

    test "row links to the show page", %{
      conn: conn,
      user: user,
      generation_environment: generation_environment
    } do
      conn = log_in_user(conn, user)

      {:ok, view, _html} = live(conn, ~p"/admin/generation_environments")

      assert view
             |> element(
               "a[href='/admin/generation_environments/#{generation_environment.id}']",
               "Show"
             )
             |> has_element?()
    end
  end

  describe "Index with in-use environment" do
    setup [:insert_user, :insert_current_generation_environment]

    test "renders the In Use badge for the matching row", %{conn: conn, user: user} do
      conn = log_in_user(conn, user)

      {:ok, view, _html} = live(conn, ~p"/admin/generation_environments")

      assert has_element?(view, ".e2e-active-badge")
    end
  end

  describe "Show" do
    setup [:insert_user, :insert_generation_environment]

    test "displays environment details and its associated records", %{
      conn: conn,
      user: user,
      generation_environment: generation_environment
    } do
      conn = log_in_user(conn, user)

      {:ok, _view, html} =
        live(conn, ~p"/admin/generation_environments/#{generation_environment.id}")

      assert html =~ "Generation Environment #{generation_environment.id}"

      assert html =~ "Model Config Provider"
      assert html =~ generation_environment.model_config_provider.id
      assert html =~ generation_environment.model_config_provider.name
      assert html =~ generation_environment.model_config_provider.provider.name
      assert html =~ generation_environment.model_config_provider.model_config.name

      assert html =~ "System Prompt"
      assert html =~ generation_environment.system_prompt.id
      assert html =~ generation_environment.system_prompt.prompt

      assert html =~ "Generation Prompt"
      assert html =~ generation_environment.generation_prompt.id

      assert html =~ "Updated At"
    end

    test "does not show an active badge when the environment is not in use", %{
      conn: conn,
      user: user,
      generation_environment: generation_environment
    } do
      conn = log_in_user(conn, user)

      {:ok, view, _html} =
        live(conn, ~p"/admin/generation_environments/#{generation_environment.id}")

      refute has_element?(view, ".e2e-active-badge")
    end

    test "does not show create/delete actions (read-only)", %{
      conn: conn,
      user: user,
      generation_environment: generation_environment
    } do
      conn = log_in_user(conn, user)

      {:ok, view, _html} =
        live(conn, ~p"/admin/generation_environments/#{generation_environment.id}")

      refute has_element?(view, "button", "Delete")
      refute has_element?(view, "a", "New")
      refute has_element?(view, "a", "Edit")
    end
  end

  describe "Show with in-use environment" do
    setup [:insert_user, :insert_current_generation_environment]

    test "renders the In Use badge in the top list", %{
      conn: conn,
      user: user,
      generation_environment: generation_environment
    } do
      conn = log_in_user(conn, user)

      {:ok, view, _html} =
        live(conn, ~p"/admin/generation_environments/#{generation_environment.id}")

      assert has_element?(view, ".e2e-active-badge")
    end
  end
end
