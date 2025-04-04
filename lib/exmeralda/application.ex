defmodule Exmeralda.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    Appsignal.Phoenix.LiveView.attach()

    children =
      [
        ExmeraldaWeb.Telemetry,
        Exmeralda.Repo,
        {DNSCluster, query: Application.get_env(:exmeralda, :dns_cluster_query) || :ignore},
        {Phoenix.PubSub, name: Exmeralda.PubSub},
        # Start the Finch HTTP client for sending emails
        {Finch, name: Exmeralda.Finch},
        # Start a worker by calling: Exmeralda.Worker.start_link(arg)
        # {Exmeralda.Worker, arg},
        # Start to serve requests, typically the last entry
        ExmeraldaWeb.Endpoint,
        {Oban, Application.fetch_env!(:exmeralda, Oban)},
        {Task.Supervisor, name: Exmeralda.TaskSupervisor}
      ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Exmeralda.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    ExmeraldaWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
