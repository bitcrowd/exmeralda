defmodule Exmeralda.Repo.Migrations.CreateSystemPrompts do
  use Ecto.Migration

  @default_prompt """
  You are an expert in Elixir programming with in-depth knowledge of Elixir.
  Provide accurate information based on the provided context to assist Elixir
  developers. Include code snippets and examples to illustrate your points.
  Respond in a professional yet approachable manner.
  Be concise for straightforward queries, but elaborate when necessary to
  ensure clarity and understanding. Adapt your responses to the complexity of
  the question. For basic usage, provide clear examples. For advanced topics,
  offer detailed explanations and multiple solutions if applicable.
  Include references to official documentation or reliable sources to support
  your answers. Ensure information is current, reflecting the latest updates
  in the library. If the context does not provide enough information, state
  this in your answer and keep it short. If you are unsure what kind of
  information the user needs, please ask follow-up questions.
  """

  def change do
    create table(:system_prompts) do
      add :prompt, :text, null: false

      timestamps()
    end

    execute(
      """
        INSERT INTO system_prompts (id, prompt, inserted_at, updated_at)
        VALUES (gen_random_uuid(), '#{@default_prompt}', NOW(), NOW())
      """,
      ""
    )

    alter table(:generation_environments) do
      add :system_prompt_id, references(:system_prompts, on_delete: :restrict), null: true
    end

    drop unique_index(:generation_environments, [:model_config_provider_id])
    create unique_index(:generation_environments, [:model_config_provider_id, :system_prompt_id])

    execute(
      """
        UPDATE generation_environments
        SET system_prompt_id = system_prompts.id
        FROM system_prompts
      """,
      ""
    )

    alter table(:generation_environments) do
      modify :system_prompt_id, references(:system_prompts, on_delete: :restrict),
        null: false,
        from: references(:system_prompts, on_delete: :restrict)
    end
  end
end
