defmodule Exmeralda.LLM.SystemPrompt do
  @moduledoc """
  System prompt that is passed to the LLM model.
  """
  use Exmeralda.Schema

  schema "system_prompts" do
    field :prompt, :string

    timestamps()
  end
end
