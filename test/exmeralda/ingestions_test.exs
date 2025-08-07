defmodule Exmeralda.IngestionsTest do
  use Exmeralda.DataCase

  alias Exmeralda.Ingestions
  alias Exmeralda.Ingestions.DeliverIngestionInProgressEmailWorker

  setup do
    user = insert(:user)

    %{user: user}
  end

  describe "notify_user/2" do
    test "inserts DeliverNotificationWorker for user", %{user: user} do
      assert {:ok, _job} = Ingestions.notify_user(user, "hop")

      assert_enqueued(
        worker: DeliverIngestionInProgressEmailWorker,
        args: %{name: user.name, email: user.email, library_name: "hop"}
      )
    end
  end
end
