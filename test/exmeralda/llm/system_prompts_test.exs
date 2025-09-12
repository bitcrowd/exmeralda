defmodule Exmeralda.LLM.SystemPromptsTest do
  use Exmeralda.DataCase
  alias Exmeralda.LLM.{SystemPrompts, SystemPrompt}
  alias Exmeralda.Repo

  describe "list_system_prompts/1" do
    test "returns the lists of system prompts ordered by creation date" do
      deletable_system_prompt =
        insert(:system_prompt, inserted_at: ~U[2022-09-10 08:27:53.023055Z])

      non_deletable_system_prompt =
        insert(:system_prompt, inserted_at: ~U[2022-08-10 08:27:53.023055Z])

      # Two generation environment to check that the left_join doesn't cause duplicated rows
      insert(:generation_environment, system_prompt: non_deletable_system_prompt)
      insert(:generation_environment, system_prompt: non_deletable_system_prompt)

      assert {:ok, {[_migration_system_prompt, system_prompt_a, system_prompt_b], _meta}} =
               SystemPrompts.list_system_prompts(%{})

      assert system_prompt_a.id == deletable_system_prompt.id
      assert system_prompt_a.deletable

      assert system_prompt_b.id == non_deletable_system_prompt.id
      refute system_prompt_b.deletable
    end
  end

  describe "create_system_prompt/1" do
    test "with valid data creates a system_prompt" do
      valid_attrs = %{prompt: "some prompt"}

      assert {:ok, %SystemPrompt{} = system_prompt} =
               SystemPrompts.create_system_prompt(valid_attrs)

      assert system_prompt.prompt == "some prompt"
    end

    test "create_system_prompt/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = SystemPrompts.create_system_prompt(%{})
    end
  end

  describe "delete_system_prompt/1 when the system prompt does not exist" do
    test "returns ok" do
      assert SystemPrompts.delete_system_prompt(uuid()) == :ok
    end
  end

  describe "delete_system_prompt/1 when the system prompt is used" do
    test "returns an error" do
      system_prompt = insert(:system_prompt)
      insert(:generation_environment, system_prompt: system_prompt)
      assert SystemPrompts.delete_system_prompt(system_prompt.id) == {:error, :system_prompt_used}
    end
  end

  describe "delete_system_prompt/" do
    test "deletes the system prompt" do
      system_prompt = insert(:system_prompt)
      assert SystemPrompts.delete_system_prompt(system_prompt.id) == :ok
      refute Repo.reload(system_prompt)
    end
  end
end
