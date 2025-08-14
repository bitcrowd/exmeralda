defmodule Exmeralda.Rag.Fake do
  @moduledoc false
  @behaviour Rag.Ai.Provider

  @type t :: %__MODULE__{}
  defstruct embeddings_model: "fake"

  @raise_for_chunk "please raise when running this embedding"

  @impl Rag.Ai.Provider
  def new(attrs) do
    struct!(__MODULE__, attrs)
  end

  @impl Rag.Ai.Provider
  def generate_embeddings(%__MODULE__{}, texts, _opts) do
    if @raise_for_chunk in texts do
      raise KeyError
    else
      {:ok, Enum.map(texts, fn _ -> Enum.map(1..768, fn _ -> :rand.uniform() end) end)}
    end
  end

  @impl Rag.Ai.Provider
  def generate_text(_provider, _prompt, _opts) do
    raise "not implemented"
  end
end
