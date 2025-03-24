import Config

config :exmeralda, Exmeralda.Mailer, adapter: Swoosh.Adapters.Local

if config_env() in [:dev, :test] do
  config :swoosh, :api_client, false
end

if config_env() == :test do
  config :exmeralda, Exmeralda.Mailer, adapter: Swoosh.Adapters.Test
end

if config_env() == :prod do
  config :swoosh, api_client: Swoosh.ApiClient.Finch, finch_name: Exmeralda.Finch
  config :swoosh, local: false
end
