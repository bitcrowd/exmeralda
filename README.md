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

The production environment does not run with Ollama. Instead we use various LLM API providers.

For example, if you need to test the chatbot against the Together AI api, first run the seeds with
`mix seed` and then change the dev config to:

```
config :exmeralda,
  llm_api_keys: %{together_ai: <<<TOGETHER API KEY>>>},
  llm_config: %{
    model_config_provider_id: "073a0faf-024b-4144-b0f0-e1f906968d08"
  }
```

This works because the provider and model config for Together AI is seeded in the dev environment. To use another provider like Lambda AI, Hyperbolic AI, or Groq AI, another `Provider` and `ModelConfigProvider` record has to be created. Then you can use its ID and set it as the `model_config_provider_id` in the config. Check the [test/support/seeds.ex](test/support/seeds.ex) file as well for inspiration. It is also possible to change the model being used by creating another `ModelConfig` record. For more details check [docs/model.png](docs/model.png) and the modules documentation.


## Dev tools

- http://localhost:4000/dev/mailbox for the Swoosh dev mailbox
- http://localhost:4000/oban for the Oban dashboard
- http://localhost:4000/admin for our admin interface

## Download regeneration (dev only)

To regenerate a set of assistant messages for a different generation environment, do the following:

1. Create the generation environment in the console - or get its ID if it already exists
2. Get the message IDs (with role: :assistant) that you want to regenerate
3. Start an iex console and run: `Exmeralda.Regenerations.download([<<< MESSAGE IDs >>>], <<< GENERATION_ENVIRONMENT ID >>>)`.

Running this function will create a copy of the original chat session and all previous messages for each message, as well as their sources. The results will be downloaded in a JSON file locally.

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

