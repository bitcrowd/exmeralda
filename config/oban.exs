import Config

config :exmeralda, Oban,
  engine: Oban.Engines.Basic,
  queues: [ingest: 10, query: 20, emails: 1, poll_ingestion: 5],
  repo: Exmeralda.Repo,
  plugins: [
    {Oban.Plugins.Pruner, max_age: 60 * 60 * 24 * 7},
    Oban.Plugins.Lifeline,
    Oban.Plugins.Reindexer
  ]

if config_env() == :test do
  config :exmeralda, Oban, testing: :manual
end
