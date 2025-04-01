defmodule Exmeralda.Chats.LLM do
  alias LangChain.Chains.{LLMChain, TextToTitleChain}

  def stream_responses(messages, handler) do
    %{llm: llm()}
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

  def generate_title(input) do
    %{
      llm: llm(),
      input_text: input
    }
    |> TextToTitleChain.new!()
  end

  defp llm do
    case Application.fetch_env!(:exmeralda, :llm) do
      llm when is_struct(llm) -> llm
      mod when is_atom(mod) -> mod.new(%{})
    end
  end

  defp system_prompt do
    Application.fetch_env!(:exmeralda, :system_prompt)
  end
end
