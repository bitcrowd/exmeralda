defmodule Exmeralda.Rag.Ollama do
  @moduledoc false
  @behaviour Rag.Ai.Provider

  require Logger

  @type t :: %__MODULE__{
          embeddings_url: String.t() | nil,
          embeddings_model: String.t() | nil
        }
  defstruct embeddings_url: "http://localhost:11434/api/embed",
            embeddings_model: nil

  @impl Rag.Ai.Provider
  def new(attrs) do
    struct!(__MODULE__, attrs)
  end

  @impl Rag.Ai.Provider
  def generate_embeddings(%__MODULE__{} = provider, texts, _opts \\ []) do
    req_params =
      [
        json: %{"model" => provider.embeddings_model, "input" => texts}
      ]

    case Req.post(provider.embeddings_url, req_params) do
      {:ok, %Req.Response{status: 200} = response} ->
        {:ok, get_embeddings(response)}

      {:ok, %Req.Response{status: status, body: body}} ->
        Logger.error("HTTP request failed with status code #{status}, body: #{inspect(body)}")
        {:error, "HTTP request failed with status code #{status}, body: #{inspect(body)}"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp get_embeddings(response) do
    get_in(response.body, ["embeddings"])
  end

  @impl Rag.Ai.Provider
  def generate_text(_provider, _prompt, _opts \\ []) do
    raise "not implemented"
  end
end
