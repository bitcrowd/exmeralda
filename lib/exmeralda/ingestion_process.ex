defmodule Exmeralda.IngestionProcess do
  alias Exmeralda.IngestionProcess.DeliverIngestionInProgressEmailWorker

  def notify_user(user) do
    user
    |> Map.take([:name, :email])
    |> DeliverIngestionInProgressEmailWorker.new()
    |> Oban.insert()
  end
end
