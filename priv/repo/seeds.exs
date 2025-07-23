# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs

{:ok, _} = Application.ensure_all_started(:ex_machina)

import Exmeralda.Factory

# Insert ecto
libraries = [
  insert(:library),
  insert(:library,
    name: "chromic_pdf",
    version: "1.17.0",
    dependencies:
      deps_to_model([
        {:jason, "~> 1.1"},
        {:nimble_pool, "~> 0.2 or ~> 1.0"},
        {:plug, "~> 1.11", optional: true},
        {:plug_crypto, "~> 1.2 or ~> 2.0", optional: true},
        {:phoenix_html, "~> 2.14 or ~> 3.3 or ~> 4.0", optional: true},
        {:telemetry, "~> 0.4 or ~> 1.0"},
        {:websockex, ">= 0.4.3", optional: true}
      ])
  ),
  insert(:library,
    name: "carbonite",
    version: "0.15.0",
    dependencies:
      deps_to_model([
        {:ecto_sql, "~> 3.10"},
        {:jason, "~> 1.2"},
        {:postgrex, "~> 0.15 and >= 0.15.11"}
      ])
  )
]

for library <- libraries do
  ingestion = insert(:ingestion, library: library)
  insert(:chunk, library: library, ingestion: ingestion)
end
