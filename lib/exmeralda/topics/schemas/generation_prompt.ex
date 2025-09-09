defmodule Exmeralda.Topics.GenerationPrompt do
  @moduledoc """
  Generation prompt that is passed to the RAG generation builder.

  The `prompt` string can contain two placeholders:
  - `%{query}`
  - `%{context}`

  The query being the question from the user, and the context is provided
  by the ingestion's chunks.
  """
  use Exmeralda.Schema

  schema "generation_prompts" do
    field :prompt, :string

    timestamps()
  end
end
