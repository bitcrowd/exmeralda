import Config

# Configure tailwind (the version is required)
config :tailwind,
  version: "3.4.3",
  exmeralda: [
    args: ~w(
      --config=tailwind.config.js
      --input=css/app.css
      --output=../priv/static/assets/app.css
    ),
    cd: Path.expand("../assets", __DIR__)
  ]
