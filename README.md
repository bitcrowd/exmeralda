# Exmeralda

Check it out yourself at [exmeralda.chat](https://exmeralda.chat).

## Prerequisites

- Erlang & Elixir
- Node JS
- Postgres 17 (with [pgvector](https://github.com/pgvector/pgvector))

You can install all of it (except pgvector) with [asdf](https://github.com/asdf-vm/asdf).

## Setup

To test the chatbot locally you either need to start with a Groq API key (see 1password):

`GROQ_API_KEY=abcd JINA_API_KEY=abcd iex -S mix phx.server`

 or install [Ollama](https://github.com/ollama/ollama):

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

## Run

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

Be aware that the seeded libraries are not that useful to chat with, since it is just dummy data.

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

## Dev tools

- http://localhost:4000/dev/mailbox for the Swoosh dev mailbox
- http://localhost:4000/oban for the Oban dashboard
- http://localhost:4000/admin for our admin interface
