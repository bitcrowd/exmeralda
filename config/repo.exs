import Config

config :exmeralda,
  ecto_repos: [Exmeralda.Repo],
  generators: [timestamp_type: :utc_datetime_usec, binary_id: true]

config :exmeralda,
       Exmeralda.Repo,
       migration_primary_key: [type: :binary_id],
       migration_timestamps: [type: :utc_datetime_usec]

if config_env() in [:dev, :test] do
  config :exmeralda, Exmeralda.Repo,
    username: "postgres",
    password: "postgres",
    hostname: "localhost"
end

if config_env() == :dev do
  config :exmeralda, Exmeralda.Repo,
    stacktrace: true,
    show_sensitive_data_on_connection_error: true,
    pool_size: 10,
    database: "exmeralda_dev"
end

if config_env() == :test do
  config :exmeralda, Exmeralda.Repo,
    database: "exmeralda_test#{System.get_env("MIX_TEST_PARTITION")}",
    pool: Ecto.Adapters.SQL.Sandbox,
    pool_size: System.schedulers_online() * 2
end
