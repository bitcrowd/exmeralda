# Exmeralda

Check it out yourself at [exmeralda.chat](https://exmeralda.chat).

## Prerequisits 

- Erlang & Elixir
- Node JS
- Postgres (with [pgvector](https://github.com/pgvector/pgvector))

You can install all of it (except pgvector) with [asdf](https://github.com/asdf-vm/asdf). 

---

**If you have Docker installed, you can use Docker Compose to start the required services:**

The repository provides a `docker-compose.yml` file that will start both Postgres (with pgvector) and Ollama for you. This is a convenient way to get up and running without installing dependencies manually.

To start the services, run:

```sh
docker compose up -d
```

---

To start your Phoenix server:

  * Run `mix setup` to install and setup dependencies

    The `mix setup` alias will:
    - Fetch and install all Elixir dependencies (`mix deps.get`)
    - Create and migrate the database, and seed it with initial data (`mix ecto.setup`)
    - Install Tailwind, esbuild, and npm dependencies for assets (`mix assets.setup`)
    - Build frontend assets using Tailwind and esbuild (`mix assets.build`)

  * Start Phoenix endpoint with `mix phx.server` or inside IEx with `iex -S mix phx.server`

To test the chatbot locally you either need to start with a Groq API key (see 1password):

`GROQ_API_KEY=abcd JINA_API_KEY=abcd iex -S mix phx.server`

 or install Ollama:
 
```sh
brew install ollama 
ollama pull llama3.2:latest
ollama pull unclemusclez/jina-embeddings-v2-base-code
```

and then start as usual:

```sh
mix phx.server
```

or 

```sh
iex -S mix phx.server
```

Be aware that the seeded libraries are not that useful to chat with, since it is just dummy data.

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

