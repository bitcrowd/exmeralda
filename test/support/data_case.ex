defmodule Exmeralda.DataCase do
  @moduledoc """
  This module defines the setup for tests requiring
  access to the application's data layer.

  You may define functions here to be used as helpers in
  your tests.

  Finally, if the test case interacts with the database,
  we enable the SQL sandbox, so changes done to the database
  are reverted at the end of every test. If you are using
  PostgreSQL, you can even run database tests asynchronously
  by setting `use Exmeralda.DataCase, async: true`, although
  this option is not recommended for other databases.
  """

  use ExUnit.CaseTemplate
  import Ecto.Query

  using do
    quote do
      use Oban.Testing, repo: Exmeralda.Repo

      import Ecto
      import Ecto.Changeset
      import Ecto.Query
      import Exmeralda.DataCase
      import Exmeralda.Factory
      import BitcrowdEcto.Assertions
      import BitcrowdEcto.Random, only: [uuid: 0]
      import Swoosh.TestAssertions

      alias Exmeralda.Repo
    end
  end

  setup tags do
    Exmeralda.DataCase.setup_sandbox(tags)
    :ok
  end

  @doc """
  Sets up the sandbox based on the test tags.
  """
  def setup_sandbox(tags) do
    pid = Ecto.Adapters.SQL.Sandbox.start_owner!(Exmeralda.Repo, shared: not tags[:async])
    on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(pid) end)
  end

  @doc """
  A helper that transforms changeset errors into a map of messages.

      assert {:error, changeset} = Accounts.create_user(%{password: "short"})
      assert "password is too short" in errors_on(changeset).password
      assert %{password: ["password is too short"]} = errors_on(changeset)

  """
  def errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Regex.replace(~r"%{(\w+)}", message, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
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

  def test_model_config_provider_id, do: "9a21bfd3-cb0a-433c-a9b3-826143782c81"
  def test_generation_prompt_id, do: "a6dd3ab3-d57e-43d9-a39a-d1ce58a43cc0"

  def retry_job do
    {:ok, 1} =
      Oban.Job
      |> where([o], o.state in ["scheduled", "retryable"])
      |> Oban.retry_all_jobs()
  end
end
