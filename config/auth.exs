import Config

config :exmeralda, :auth_strategy, Assent.Strategy.Github

if config_env() in [:dev, :test] do
  config :exmeralda, :auth_strategy, ExmeraldaWeb.GithubMock
end
