defmodule Exmeralda.Chats.LLM do
  alias LangChain.Chains.LLMChain
  alias Exmeralda.Environment.GenerationConfig
  alias Exmeralda.Repo

  def stream_responses(messages, generation_config_id, handler) do
    %{llm: llm(generation_config_id)}
    |> LLMChain.new!()
    |> LLMChain.add_message(system_prompt() |> LangChain.Message.new_system!())
    |> LLMChain.add_messages(Enum.map(messages, &to_langchain_message/1))
    |> LLMChain.add_callback(handler)
    |> LLMChain.run()
  end

  defp to_langchain_message(%{role: :system, content: content}),
    do: LangChain.Message.new_system!(content)

  defp to_langchain_message(%{role: :user, content: content}),
    do: LangChain.Message.new_user!(content)

  defp to_langchain_message(%{role: :assistant, content: content}),
    do: LangChain.Message.new_assistant!(content)

  defp llm(generation_config_id) do
    generation_config =
      Repo.get!(GenerationConfig, generation_config_id)
      |> Repo.preload([:model_config, :provider])

    params =
      %{
        "model" => generation_config.model_config_provider.name
      }
      |> Map.merge(generation_config.model_config.config)
      |> maybe_add_endpoint(generation_config.provider)
      |> maybe_add_api_key(generation_config.provider)

    llm_mod = Application.fetch_env!(:exmeralda, :llm)
    llm_mod.new!(params)
  end

  defp maybe_add_api_key(params, %{type: type}) do
    api_keys = Application.fetch_env!(:exmeralda, :llm_api_keys)

    if api_key = Map.get(api_keys, type) do
      Map.put(params, "api_key", api_key)
    else
      params
    end
  end

  defp maybe_add_endpoint(params, %{type: :mock}), do: params

  defp maybe_add_endpoint(params, %{endpoint: endpoint}),
    do: Map.put(params, "endpoint", endpoint)

  defp system_prompt do
    Application.fetch_env!(:exmeralda, :system_prompt)
  end
end
