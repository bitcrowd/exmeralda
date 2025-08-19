defmodule Exmeralda.Topics.DeliverIngestionInProgressEmailWorkerTest do
  use Exmeralda.DataCase

  alias Exmeralda.Topics.DeliverIngestionInProgressEmailWorker

  defp insert_user(_) do
    %{user: insert(:user)}
  end

  describe "perform/1 when user does not exist" do
    test "cancels the worker" do
      assert perform_job(DeliverIngestionInProgressEmailWorker, %{
               user_id: uuid(),
               library_id: uuid()
             }) == {:cancel, :user_not_found}
    end
  end

  describe "perform/1 when the library does not exist" do
    setup [:insert_user]

    test "cancels the worker", %{user: user} do
      assert perform_job(DeliverIngestionInProgressEmailWorker, %{
               user_id: user.id,
               library_id: uuid()
             }) == {:cancel, :library_not_found}
    end
  end

  describe "perform/1" do
    setup [:insert_user]

    test "delivers email to user", %{user: user} do
      library = insert(:library, name: "rag")

      assert {:ok, _} =
               perform_job(DeliverIngestionInProgressEmailWorker, %{
                 user_id: user.id,
                 library_id: library.id
               })

      assert_email_sent(
        subject: "We are ingesting the package rag for you",
        to: {user.name, user.email}
      )
    end
  end
end
