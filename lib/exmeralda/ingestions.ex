defmodule Exmeralda.Ingestions do
  alias Exmeralda.Ingestions.DeliverIngestionInProgressEmailWorker

  def notify_user(user, library_name) do
    params = %{name: user.name, email: user.email, library_name: library_name}

    DeliverIngestionInProgressEmailWorker.new(params)
    |> Oban.insert()
  end
end
