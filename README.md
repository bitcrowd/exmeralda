# Exmeralda

## Prerequisits 

- Erlang & Elixir
- Node JS
- Postgres (with [pgvector](https://github.com/pgvector/pgvector))

You can install all of it (except pgvector) with [asdf](https://github.com/asdf-vm/asdf). 

To start your Phoenix server:

  * Run `mix setup` to install and setup dependencies
  * Start Phoenix endpoint with `mix phx.server` or inside IEx with `iex -S mix phx.server`

To test the chatbot locally you either need to start with a Groq API key (see 1password):

`GROQ_API_KEY=abcd iex -S mix phx.server`

 or install Ollama:
 
```sh
brew install ollama 
ollama pull llama3.2:latest
```

and then start as usual:

```sh
mix phx.server
```

or 

```sh
iex -S mix phx.server
```

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

