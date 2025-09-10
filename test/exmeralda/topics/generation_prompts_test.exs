defmodule Exmeralda.Topics.GenerationPromptsTest do
  use Exmeralda.DataCase
  alias Exmeralda.Topics.{GenerationPrompts, GenerationPrompt}
  alias Exmeralda.Repo

  describe "list_generation_prompts/1" do
    test "returns the lists of system prompts ordered by creation date" do
      deletable_generation_prompt =
        insert(:generation_prompt, inserted_at: ~U[2022-09-10 08:27:53.023055Z])

      non_deletable_generation_prompt =
        insert(:generation_prompt, inserted_at: ~U[2022-08-10 08:27:53.023055Z])

      # Two generation environment to check that the left_join doesn't cause duplicated rows
      insert(:generation_environment, generation_prompt: non_deletable_generation_prompt)
      insert(:generation_environment, generation_prompt: non_deletable_generation_prompt)

      assert {:ok,
              {[_migration_generation_prompt, generation_prompt_a, generation_prompt_b], _meta}} =
               GenerationPrompts.list_generation_prompts(%{})

      assert generation_prompt_a.id == deletable_generation_prompt.id
      assert generation_prompt_a.deletable

      assert generation_prompt_b.id == non_deletable_generation_prompt.id
      refute generation_prompt_b.deletable
    end
  end

  describe "create_generation_prompt/1" do
    test "with valid data creates a generation_prompt" do
      valid_attrs = %{prompt: "some prompt"}

      assert {:ok, %GenerationPrompt{} = generation_prompt} =
               GenerationPrompts.create_generation_prompt(valid_attrs)

      assert generation_prompt.prompt == "some prompt"
    end

    test "create_generation_prompt/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = GenerationPrompts.create_generation_prompt(%{})
    end
  end

  describe "delete_generation_prompt/1 when the system prompt does not exist" do
    test "returns ok" do
      assert GenerationPrompts.delete_generation_prompt(uuid()) == :ok
    end
  end

  describe "delete_generation_prompt/1 when the system prompt is used" do
    test "returns an error" do
      generation_prompt = insert(:generation_prompt)
      insert(:generation_environment, generation_prompt: generation_prompt)

      assert GenerationPrompts.delete_generation_prompt(generation_prompt.id) ==
               {:error, :generation_prompt_used}
    end
  end

  describe "delete_generation_prompt/" do
    test "deletes the system prompt" do
      generation_prompt = insert(:generation_prompt)
      assert GenerationPrompts.delete_generation_prompt(generation_prompt.id) == :ok
      refute Repo.reload(generation_prompt)
    end
  end
end
