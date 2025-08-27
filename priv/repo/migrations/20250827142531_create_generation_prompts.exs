defmodule Exmeralda.Repo.Migrations.CreateGenerationPrompts do
  use Ecto.Migration

  @default_prompt """
  Context information is below.
  ---------------------
  %{context}
  ---------------------
  Given the context information and no prior knowledge, answer the query.
  Query: %{query}
  Answer:
  """

  def change do
    create table(:generation_prompts) do
      add :prompt, :text, null: false

      timestamps()
    end

    execute(
      """
        INSERT INTO generation_prompts (id, prompt, inserted_at, updated_at)
        VALUES (gen_random_uuid(), '#{@default_prompt}', NOW(), NOW())
      """,
      ""
    )

    alter table(:generation_environments) do
      add :generation_prompt_id, references(:generation_prompts, on_delete: :restrict), null: true
    end

    drop unique_index(:generation_environments, [:model_config_provider_id, :system_prompt_id])

    create unique_index(
             :generation_environments,
             [
               :model_config_provider_id,
               :system_prompt_id,
               :generation_prompt_id
             ],
             name: "generation_environments_unique"
           )

    execute(
      """
        UPDATE generation_environments
        SET generation_prompt_id = generation_prompts.id
        FROM generation_prompts
      """,
      ""
    )

    alter table(:generation_environments) do
      modify :generation_prompt_id, references(:generation_prompts, on_delete: :restrict),
        null: false,
        from: references(:generation_prompts, on_delete: :restrict)
    end
  end
end
