defmodule Exmeralda.Ingestions.DeliverIngestionInProgressEmailWorkerTest do
  use Exmeralda.DataCase

  alias Exmeralda.Ingestions.DeliverIngestionInProgressEmailWorker

  setup do
    user = insert(:user)

    %{user: user}
  end

  describe "perform/1" do
    test "delivers email to user", %{user: user} do
      library_name = "rag"

      assert {:ok, _} =
               perform_job(DeliverIngestionInProgressEmailWorker, %{
                 name: user.name,
                 email: user.email,
                 library_name: library_name
               })

      assert_email_sent(
        subject: "We are ingesting the package #{library_name} for you",
        to: {user.name, user.email}
      )
    end
  end
end
