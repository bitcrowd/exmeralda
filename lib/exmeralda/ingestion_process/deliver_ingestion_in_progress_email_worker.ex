defmodule Exmeralda.IngestionProcess.DeliverIngestionInProgressEmailWorker do
  use Oban.Worker, queue: :emails, max_attempts: 5
  alias Exmeralda.{Emails, Mailer}

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"name" => name, "email" => email}}) do
    Emails.ingestion_in_progress_email(%{name: name, email: email})
    |> Mailer.deliver()
  end
end
