defmodule Exmeralda.IngestionProcess.DeliverIngestionInProgressEmailWorkerTest do
  use Exmeralda.DataCase

  alias Exmeralda.IngestionProcess.DeliverIngestionInProgressEmailWorker

  setup do
    user = insert(:user)

    %{user: user}
  end

  describe "perform/1" do
    test "delivers email to user", %{user: user} do
      assert {:ok, _} =
               perform_job(DeliverIngestionInProgressEmailWorker, %{
                 name: user.name,
                 email: user.email
               })

      assert_email_sent(subject: "We are ingesting your library", to: {user.name, user.email})
    end
  end
end
