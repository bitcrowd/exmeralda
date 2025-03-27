import Config

config :exmeralda, Oban,
  engine: Oban.Engines.Basic,
  queues: [ingest: 5, query: 20],
  repo: Exmeralda.Repo,
  plugins: [{Oban.Plugins.Pruner, max_age: 60 * 60 * 24 * 7}]

if config_env() == :test do
  config :exmeralda, Oban, testing: :manual
end
