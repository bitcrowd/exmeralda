import Config

config :exmeralda, ExmeraldaWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: ExmeraldaWeb.ErrorHTML, json: ExmeraldaWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Exmeralda.PubSub,
  live_view: [signing_salt: "/BW3ebs9"]

if config_env() == :dev do
  config :exmeralda, ExmeraldaWeb.Endpoint,
    http: [ip: {127, 0, 0, 1}, port: 4000],
    check_origin: false,
    code_reloader: true,
    debug_errors: true,
    secret_key_base: "/GwtPNvlBTaun6McVZF8JMYsyDT48JxkyvB9y4CwmZ8sSsab3d/AkadAkXTZOBTn",
    watchers: [
      esbuild: {Esbuild, :install_and_run, [:exmeralda, ~w(--sourcemap=inline --watch)]},
      tailwind: {Tailwind, :install_and_run, [:exmeralda, ~w(--watch)]}
    ],
    live_reload: [
      patterns: [
        ~r"priv/static/(?!uploads/).*(js|css|png|jpeg|jpg|gif|svg)$",
        ~r"priv/gettext/.*(po)$",
        ~r"lib/exmeralda_web/(controllers|live|components)/.*(ex|heex)$"
      ]
    ]
end

if config_env() == :test do
  config :exmeralda, ExmeraldaWeb.Endpoint,
    http: [ip: {127, 0, 0, 1}, port: 4002],
    secret_key_base: "I2MVHJ9Jf60q712GQJZ5Zyu4hqj7pFrWy0VtLS/jhUiFlqUTI3j3a3MV1F4Pw8H9",
    server: false
end

if config_env() == :prod do
  config :exmeralda, ExmeraldaWeb.Endpoint,
    cache_static_manifest: "priv/static/cache_manifest.json"
end
