defmodule Exmeralda.Topics.DeliverIngestionInProgressEmailWorker do
  use Oban.Worker, queue: :emails, max_attempts: 2
  alias Exmeralda.{Emails, Mailer, Repo}
  alias Exmeralda.Accounts.User
  alias Exmeralda.Topics.Library

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"user_id" => user_id, "library_id" => library_id}}) do
    with {:ok, user} <- fetch_user(user_id),
         {:ok, library} <- fetch_library(library_id) do
      # TODO: library.name is not null: false...
      Emails.ingestion_in_progress_email(%{name: user.name, email: user.email}, library.name)
      |> Mailer.deliver()
    end
  end

  defp fetch_user(user_id) do
    case Repo.fetch(User, user_id) do
      {:ok, user} -> {:ok, user}
      {:error, {:not_found, _}} -> {:cancel, :user_not_found}
    end
  end

  defp fetch_library(library_id) do
    case Repo.fetch(Library, library_id) do
      {:ok, library} -> {:ok, library}
      {:error, {:not_found, _}} -> {:cancel, :library_not_found}
    end
  end
end
