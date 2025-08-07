defmodule Exmeralda.IngestionProcessTest do
  use Exmeralda.DataCase

  alias Exmeralda.IngestionProcess
  alias Exmeralda.IngestionProcess.DeliverIngestionInProgressEmailWorker

  setup do
    user = insert(:user)

    %{user: user}
  end

  describe "notify_user/2" do
    test "inserts DeliverNotificationWorker for user", %{user: user} do
      assert {:ok, _job} = IngestionProcess.notify_user(user, "hop")

      assert_enqueued(
        worker: DeliverIngestionInProgressEmailWorker,
        args: %{name: user.name, email: user.email, library_name: "hop"}
      )
    end
  end
end
