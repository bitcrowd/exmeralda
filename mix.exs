defmodule Exmeralda.MixProject do
  use Mix.Project

  def project do
    [
      app: :exmeralda,
      version: "0.1.0",
      elixir: "~> 1.14",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps()
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {Exmeralda.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(env) when env in [:dev, :test], do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      {:phoenix, "~> 1.7.20"},
      {:phoenix_ecto, "~> 4.5"},
      {:ecto, "~> 3.13"},
      {:ecto_sql, "~> 3.13"},
      {:postgrex, ">= 0.0.0"},
      {:phoenix_html, "~> 4.1"},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:phoenix_live_view, "~> 1.0.0"},
      {:floki, ">= 0.30.0"},
      {:phoenix_live_dashboard, "~> 0.8.3"},
      {:esbuild, "~> 0.8", runtime: Mix.env() == :dev},
      {:tailwind, "~> 0.2", runtime: Mix.env() == :dev},
      {:heroicons,
       github: "tailwindlabs/heroicons",
       tag: "v2.1.1",
       sparse: "optimized",
       app: false,
       compile: false,
       depth: 1},
      {:swoosh, "~> 1.19"},
      {:gen_smtp, "~> 1.3"},
      {:bitcrowd_ecto, "~> 1.0"},
      {:finch, "~> 0.13"},
      {:telemetry_metrics, "~> 1.0"},
      {:telemetry_poller, "~> 1.0"},
      {:gettext, "~> 0.26"},
      {:jason, "~> 1.2"},
      {:dns_cluster, "~> 0.1.1"},
      {:bandit, "~> 1.5"},
      {:credo, "~> 1.7", only: [:dev, :test]},
      {:ex_machina, "~> 2.8.0", only: [:dev, :test]},
      {:assent, "~> 0.3.0"},
      {:req, "~> 0.5"},
      {:req_hex, "~> 0.2.1"},
      {:langchain, "~> 0.3.0"},
      {:mdex, "~> 0.2"},
      {:oban, "~> 2.19"},
      {:oban_web, "~> 2.11"},
      {:rag, "~> 0.2.2"},
      {:pgvector, "~> 0.3.0"},
      {:flop, "~> 0.26.1"},
      {:flop_phoenix, "~> 0.24.1"},
      {:appsignal_phoenix, "~> 2.7"},
      {:nimble_csv, "~> 1.3.0", only: [:dev, :test]}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to install project dependencies and perform other setup tasks, run:
  #
  #     $ mix setup
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      setup: ["deps.get", "ecto.setup", "assets.setup", "assets.build"],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate", "test"],
      "assets.setup": [
        "tailwind.install --if-missing",
        "esbuild.install --if-missing",
        "cmd npm install --prefix assets"
      ],
      "assets.build": ["tailwind exmeralda", "esbuild exmeralda"],
      "assets.deploy": [
        "tailwind exmeralda --minify",
        "esbuild exmeralda --minify",
        "phx.digest"
      ],
      lint: [
        "format --check-formatted",
        "credo --strict"
      ],
      seed: ["run priv/repo/seeds.exs"]
    ]
  end
end
