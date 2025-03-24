import Config

config :phoenix, :json_library, Jason

if config_env() in [:dev, :test] do
  config :phoenix, :plug_init_mode, :runtime

  config :phoenix_live_view,
    enable_expensive_runtime_checks: true
end

if config_env() == :dev do
  config :exmeralda, dev_routes: true
  config :phoenix, :stacktrace_depth, 20
  config :phoenix_live_view, debug_heex_annotations: true
end
