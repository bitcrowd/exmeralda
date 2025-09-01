defmodule Exmeralda.Chats.LLM do
  alias LangChain.Chains.LLMChain
  alias Exmeralda.Chats.GenerationEnvironment
  alias Exmeralda.Repo

  def stream_responses(messages, generation_environment_id, handler) do
    generation_environment = get_generation_environment(generation_environment_id)

    %{llm: llm(generation_environment.model_config_provider)}
    |> LLMChain.new!()
    |> LLMChain.add_message(
      system_prompt(generation_environment)
      |> LangChain.Message.new_system!()
    )
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

  defp get_generation_environment(generation_environment_id) do
    GenerationEnvironment
    |> Repo.get!(generation_environment_id)
    |> Repo.preload([:system_prompt, model_config_provider: [:model_config, :provider]])
  end

  # Public for testing
  def llm(%{name: model_name, provider: provider, model_config: model_config}) do
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

  defp system_prompt(%{system_prompt: system_prompt}) do
    system_prompt.prompt
  end
end
