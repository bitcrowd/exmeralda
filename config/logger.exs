import Config

config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

if config_env() == :dev do
  config :logger, :console, format: "[$level] $message\n"
end

if config_env() == :test do
  config :logger, level: :info
end

if config_env() == :prod do
  config :logger, level: :info
end
