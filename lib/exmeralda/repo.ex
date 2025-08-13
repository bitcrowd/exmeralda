defmodule Exmeralda.Repo do
  use Ecto.Repo,
    otp_app: :exmeralda,
    adapter: Ecto.Adapters.Postgres

  use BitcrowdEcto.Repo
end
