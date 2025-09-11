import Config

# ## Using releases
#
# If you use `mix release`, you need to explicitly enable the server
# by passing the PHX_SERVER=true when you start it:
#
#     PHX_SERVER=true bin/exmeralda start
#
# Alternatively, you can use `mix phx.gen.release` to generate a `bin/server`
# script that automatically sets the env var above.
if System.get_env("PHX_SERVER") do
  config :exmeralda, ExmeraldaWeb.Endpoint, server: true
end

config :exmeralda, Assent.Strategy.Github,
  client_id: System.get_env("GITHUB_CLIENT_ID"),
  client_secret: System.get_env("GITHUB_CLIENT_SECRET")

if config_env() == :dev and not is_nil(System.get_env("GITHUB_CLIENT_ID")) do
  config :exmeralda, :auth_strategy, Assent.Strategy.Github
end

if config_env() == :prod do
  database_url =
    System.get_env("DATABASE_URL") ||
      raise """
      environment variable DATABASE_URL is missing.
      For example: ecto://USER:PASS@HOST/DATABASE
      """

  maybe_ipv6 = if System.get_env("ECTO_IPV6") in ~w(true 1), do: [:inet6], else: []

  config :exmeralda, Exmeralda.Repo,
    # ssl: true,
    url: database_url,
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10"),
    socket_options: maybe_ipv6

  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  host = System.get_env("PHX_HOST") || "example.com"
  port = String.to_integer(System.get_env("PORT") || "4000")

  config :exmeralda, :dns_cluster_query, System.get_env("DNS_CLUSTER_QUERY")

  config :exmeralda, ExmeraldaWeb.Endpoint,
    url: [host: host, port: 443, scheme: "https"],
    http: [
      ip: {0, 0, 0, 0, 0, 0, 0, 0},
      port: port
    ],
    secret_key_base: secret_key_base
end

if config_env() == :prod do
  relay = System.get_env("EMAIL_RELAY") || raise "environment variable EMAIL_RELAY is missing"

  username =
    System.get_env("EMAIL_USERNAME") || raise "environment variable EMAIL_USERNAME is missing"

  password =
    System.get_env("EMAIL_PASSWORD") || raise "environment variable EMAIL_PASSWORD is missing"

  config :exmeralda, Exmeralda.Mailer,
    adapter: Swoosh.Adapters.SMTP,
    relay: relay,
    username: username,
    password: password,
    auth: :always,
    tls: :always,
    port: 587,
    tls_options: [
      versions: [:"tlsv1.3"],
      cacerts: :public_key.cacerts_get(),
      server_name_indication: String.to_charlist(relay),
      depth: 10
    ]
end

cond do
  config_env() == :prod ->
    config :exmeralda,
      llm_api_keys: %{
        # Keys are the provider's `name` column
        "lambda_ai" => System.fetch_env!("LAMBDA_API_KEY"),
        "groq_ai" => System.fetch_env!("GROQ_API_KEY"),
        "together_ai" => System.fetch_env!("TOGETHER_API_KEY"),
        "hyperbolic_ai" => System.fetch_env!("HYPERBOLIC_API_KEY")
      },
      llm_config: %{
        # The CURRENT_LLM_MODEL_CONFIG_PROVIDER_ID must match an existing ModelConfigProvider record in the database
        model_config_provider_id: System.fetch_env!("CURRENT_LLM_MODEL_CONFIG_PROVIDER_ID"),
        system_prompt_id: System.fetch_env!("CURRENT_LLM_SYSTEM_PROMPT_ID"),
        generation_prompt_id: System.fetch_env!("CURRENT_RAG_GENERATION_PROMPT_ID")
      }

  config_env() == :dev ->
    config :exmeralda,
      llm_api_keys: %{},
      # Points to the Ollama dev config set in the seeds
      llm_config: %{
        model_config_provider_id: "1f0e49ff-a985-4c03-a89b-fa443842fa95",
        system_prompt_id: "c49195b4-daca-42af-835d-bdb928986d5c",
        generation_prompt_id: "3ef5b20b-bb71-467d-8364-898df9926a95"
      }

  true ->
    config :exmeralda,
      llm_api_keys: %{"foo_ai" => "abcde"},
      llm_config: %{
        # Random IDs that is used in the tests!
        model_config_provider_id: "9a21bfd3-cb0a-433c-a9b3-826143782c81",
        system_prompt_id: "96123e4b-7d0a-4e14-82d4-63d68562e8f1",
        generation_prompt_id: "a6dd3ab3-d57e-43d9-a39a-d1ce58a43cc0"
      }
end

cond do
  config_env() == :prod || System.get_env("JINA_API_KEY") ->
    config :exmeralda,
      embedding_api_keys: %{
        "jina" => System.fetch_env!("JINA_API_KEY")
      },
      embedding_config: %{
        type: :openai,
        model: "jina-embeddings-v2-base-code",
        provider: "jina",
        config: %{
          embeddings_url: "https://api.jina.ai/v1/embeddings"
        }
      }

  config_env() == :dev ->
    config :exmeralda,
      embedding_api_keys: %{},
      embedding_config: %{
        type: :ollama,
        provider: "ollama_ai",
        model: "unclemusclez/jina-embeddings-v2-base-code",
        config: %{}
      }

  true ->
    config :exmeralda,
      embedding_api_keys: %{},
      embedding_config: %{
        type: :mock,
        provider: "mock",
        model: "fake",
        config: %{}
      }
end

if config_env() == :prod do
  config :exmeralda, :admin_auth,
    username: "exmeralda",
    password: System.fetch_env!("ADMIN_AUTH_PASSWORD")
end
