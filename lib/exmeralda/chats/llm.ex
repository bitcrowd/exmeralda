defmodule Exmeralda.Chats.LLM do
  alias LangChain.Chains.LLMChain
  alias Exmeralda.LLM.ModelConfigProvider
  alias Exmeralda.Repo

  def stream_responses(messages, model_config_id, provider_id, handler) do
    %{llm: llm(model_config_id, provider_id)}
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

  # Public for testing
  def llm(model_config_id, provider_id) do
    %{name: model_name, provider: provider, model_config: model_config} =
      ModelConfigProvider
      |> Repo.get_by!(model_config_id: model_config_id, provider_id: provider_id)
      |> Repo.preload([:model_config, :provider])

    params =
      %{"model" => model_name}
      |> Map.merge(model_config.config)
      |> Map.merge(provider.config)
      |> maybe_add_api_key(provider)

    llm_mod(provider).new!(params)
  end

  defp maybe_add_api_key(params, %{name: name, type: :openai}) do
    api_keys = Application.fetch_env!(:exmeralda, :llm_api_keys)

    Map.put(params, "api_key", Map.get(api_keys, name))
  end

  defp maybe_add_api_key(params, _type), do: params

  defp llm_mod(%{type: type}) do
    case type do
      :mock -> Exmeralda.LLM.Fake
      :ollama -> LangChain.ChatModels.ChatOllamaAI
      :openai -> LangChain.ChatModels.ChatOpenAI
    end
  end

  defp system_prompt do
    Application.fetch_env!(:exmeralda, :system_prompt)
  end
end
