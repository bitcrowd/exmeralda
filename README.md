# Exmeralda

Check it out yourself at [exmeralda.chat](https://exmeralda.chat).

## Prerequisites

- Erlang & Elixir
- Node JS
- Postgres 17 (with [pgvector](https://github.com/pgvector/pgvector))

You can install all of it (except pgvector) with [asdf](https://github.com/asdf-vm/asdf).

## Dev Setup

The chatbot can be tested locally with [Ollama](https://github.com/ollama/ollama):

```sh
brew install ollama

# In a separate terminal
ollama start

# Then back to the initial terminal
ollama pull llama3.2:latest
ollama pull unclemusclez/jina-embeddings-v2-base-code
```

and then:

```
mix deps.get
mix setup
```

Start as usual:

```sh
# In a separate terminal
ollama start

# In another terminal
mix phx.server
```

or

```sh
iex -S mix phx.server
```

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.
To start a chat, first create a new library in the UI on the home page.

## Production-like setup

The production environment does not run with Ollama. Instead we use various LLM API providers. If you need to test the chatbot against the Together AI api, change the dev config to:

```
config :exmeralda,
  llm_api_keys: %{together: System.fetch_env!("TOGETHER_API_KEY")},
  llm: LangChain.ChatModels.ChatOpenAI,
  current_generation_config_id: "5242404c-ca9e-40f3-a84e-c044195379ed"
```

To use Lambda AI, Hyperbolic AI, Groq AI or any other provider, another `GenerationConfig` record and use its ID as the `current_generation_config_id` in the config. Check the [test/support/seeds.ex](test/support/seeds.ex) file as well for inspiration.

It is also possible to change the model being used by creating another `ModelConfig` record. For more details check [docs/model.png](docs/model.png) and the modules documentation.


## Dev tools

- http://localhost:4000/dev/mailbox for the Swoosh dev mailbox
- http://localhost:4000/oban for the Oban dashboard
- http://localhost:4000/admin for our admin interface

## Deployment

The deployment is done with [Fly.io](https://fly.io/docs/elixir/).

Follow [this guide](https://fly.io/docs/elixir/the-basics/iex-into-running-app/) to run an IEx console on production:

```sh
fly ssh console --pty -C "/app/bin/exmeralda remote"
```


### Staging

The deployment to staging is automatic when merging to the `main` branch.

### Production

To deploy to production:

```
git fetch
git checkout production
git pull
git reset --hard origin/main
git push
```

