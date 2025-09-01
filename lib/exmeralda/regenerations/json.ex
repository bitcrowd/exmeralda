defmodule Exmeralda.Regenerations.JSON do
  import Ecto.Query
  alias Exmeralda.Chats.Message
  alias Exmeralda.Repo

  def format_regeneration(assistant_message_ids) do
    from(m in Message,
      where: m.id in ^assistant_message_ids and not is_nil(m.regenerated_from_message_id),
      preload: [
        session: [ingestion: [:library]],
        generation_environment: [
          :system_prompt,
          :generation_prompt,
          model_config_provider: [:model_config, :provider]
        ]
      ]
    )
    |> Repo.all()
    |> Enum.map(fn assistant_message ->
      user_message =
        Repo.one(
          from(m in Message,
            where:
              m.session_id == ^assistant_message.session_id and
                m.index == ^assistant_message.index - 1
          )
        )

      chunks = format_chunks(assistant_message)
      generation_environment = assistant_message.generation_environment
      ingestion = assistant_message.session.ingestion

      {full_user_prompt, _} =
        Exmeralda.Topics.Rag.full_prompt(
          generation_environment.generation_prompt,
          user_message.content,
          chunks
        )

      %{
        generation_environment: format_generation_environment(generation_environment),
        ingestion: %{
          id: ingestion.id,
          library_name: ingestion.library.name,
          library_version: ingestion.library.version
        },
        generation: %{
          user_query: user_message.content,
          user_message_id: user_message.id,
          chunks: chunks,
          full_user_prompt: full_user_prompt,
          assistant_response: assistant_message.content,
          assistant_message_id: assistant_message.id
        }
      }
    end)
  end

  defp format_generation_environment(
         %{model_config_provider: %{model_config: model_config, provider: provider}} =
           generation_environment
       ) do
    embedding = Application.fetch_env!(:exmeralda, :embedding_config)

    %{
      model_name: model_config.name,
      model_provider: provider.type,
      model_provider_config:
        %{
          model: generation_environment.model_config_provider.name
        }
        |> Map.merge(model_config.config)
        |> Map.merge(provider.config),
      system_prompt: generation_environment.system_prompt.prompt,
      prompt_template: generation_environment.generation_prompt.prompt,
      embedding_model: embedding.model,
      embedding_provider: embedding.provider,
      embedding_provider_config: embedding.config,
      id: generation_environment.id
    }
  end

  defp format_chunks(assitant_message) do
    %{source_chunks: chunks} = Repo.preload(assitant_message, [:source_chunks])

    chunks
    |> Enum.map(&Map.take(&1, [:id, :source, :content]))
  end
end
