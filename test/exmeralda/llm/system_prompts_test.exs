defmodule Exmeralda.LLM.SystemPromptsTest do
  use Exmeralda.DataCase
  alias Exmeralda.LLM.{SystemPrompts, SystemPrompt}
  alias Exmeralda.Repo

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
