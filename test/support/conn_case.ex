defmodule ExmeraldaWeb.ConnCase do
  @moduledoc """
  This module defines the test case to be used by
  tests that require setting up a connection.

  Such tests rely on `Phoenix.ConnTest` and also
  import other functionality to make it easier
  to build common data structures and query the data layer.

  Finally, if the test case interacts with the database,
  we enable the SQL sandbox, so changes done to the database
  are reverted at the end of every test. If you are using
  PostgreSQL, you can even run database tests asynchronously
  by setting `use ExmeraldaWeb.ConnCase, async: true`, although
  this option is not recommended for other databases.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      # The default endpoint for testing
      @endpoint ExmeraldaWeb.Endpoint

      use ExmeraldaWeb, :verified_routes
      use Oban.Testing, repo: Exmeralda.Repo

      # Import conveniences for testing with connections
      import Plug.Conn
      import Phoenix.ConnTest
      import ExmeraldaWeb.ConnCase
      import Exmeralda.Factory
      import BitcrowdEcto.Random, only: [uuid: 0]
    end
  end

  setup tags do
    Exmeralda.DataCase.setup_sandbox(tags)
    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end

  @doc """
  Logs the given `user` into the `conn`.

  It returns an updated `conn`.
  """
  def log_in_user(conn, user) do
    conn
    |> Phoenix.ConnTest.init_test_session(%{})
    |> Plug.Conn.put_session(:user_id, user.id)
  end

  # https://elixirforum.com/t/dbconnection-error-owner-pid-exited-while-testing-async-function/54953/4
  # https://dockyard.com/blog/2024/06/06/a-better-solution-for-waiting-for-async-tasks-in-tests
  def wait_for_generation_task do
    pids = Task.Supervisor.children(Exmeralda.TaskSupervisor)

    for pid <- pids do
      ref = Process.monitor(pid)
      assert_receive {:DOWN, ^ref, _, _, _}, 100_000
    end
  end

  def test_model_config_id, do: "3846dd40-1fcd-4ba2-83d5-bd2d7f0986e7"
  def test_provider_id, do: "9a21bfd3-cb0a-433c-a9b3-826143782c81"
end
