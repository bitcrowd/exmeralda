defmodule Exmeralda.Repo.Migrations.AddActiveToSystemPrompts do
  use Ecto.Migration

  def change do
    alter table(:system_prompts) do
      add :active, :boolean, default: false, null: false
    end

    create unique_index(:system_prompts, :active, where: "active IS TRUE")

    migrate_current_system_prompt()
  end

  defp migrate_current_system_prompt do
    case Application.get_env(:exmeralda, :llm_config, %{}) do
      %{system_prompt_id: system_prompt_id} ->
        execute(
          """
            UPDATE system_prompts
            SET active = TRUE
            WHERE id = '#{system_prompt_id}';
          """,
          ""
        )

      _ ->
        execute(
          """
            UPDATE system_prompts
            SET active = TRUE
            WHERE id IN (SELECT id FROM system_prompts ORDER BY id LIMIT 1);
          """,
          ""
        )
    end
  end
end
