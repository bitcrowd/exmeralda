defmodule Exmeralda.MockLLM do
  @behaviour LangChain.ChatModels.ChatModel

  alias LangChain.{MessageDelta, Callbacks}

  defstruct name: "MockChatModel", version: "1.0", callbacks: []

  @impl true
  def call(model, _messages, _tools \\ []) do
    chunks = ["This", " is", " a", " streaming", " response"]

    deltas =
      Enum.map(chunks, fn chunk ->
        delta = %MessageDelta{role: :assistant, content: chunk, status: :incomplete}
        Callbacks.fire(model.callbacks, :on_llm_new_delta, [delta])
        # Simulating network delay
        Process.sleep(500)
        delta
      end)

    {:ok, deltas ++ [%MessageDelta{role: :assistant, content: "!", status: :complete}]}
  end

  @impl true
  def serialize_config(%__MODULE__{} = model) do
    %{
      "module" => __MODULE__ |> Atom.to_string(),
      "name" => model.name,
      "version" => model.version,
      "callbacks" => model.callbacks
    }
  end

  @impl true
  def restore_from_map(%{"name" => name, "version" => version, "callbacks" => callbacks}) do
    {:ok, %__MODULE__{name: name, version: version, callbacks: callbacks}}
  end
end
