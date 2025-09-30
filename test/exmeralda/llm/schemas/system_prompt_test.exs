defmodule Exmeralda.LLM.SystemPromptTest do
  use Exmeralda.DataCase
  alias Exmeralda.LLM.SystemPrompt

  describe "table" do
    test "only one active system prompt" do
      insert(:system_prompt, active: true)
      insert(:system_prompt, active: false)

      assert_raise Ecto.ConstraintError, ~r/system_prompts_active_index/, fn ->
        insert(:system_prompt, active: true)
      end
    end
  end

  describe "changeset/1" do
    test "is invalid for invalid attrs" do
      %{}
      |> SystemPrompt.changeset()
      |> refute_changeset_valid()
      |> assert_required_error_on(:prompt)
    end

    test "returns a changeset" do
      %{prompt: "You are a duck"}
      |> SystemPrompt.changeset()
      |> assert_changeset_valid()
      |> assert_changes(:prompt, "You are a duck")
    end
  end

  describe "activate_changeset/1" do
    test "sets active to true" do
      %SystemPrompt{}
      |> SystemPrompt.activate_changeset()
      |> assert_changes(:active, true)
    end

    test "changes active to true" do
      %SystemPrompt{active: false}
      |> SystemPrompt.activate_changeset()
      |> assert_changes(:active, true)
    end

    test "does not change already active prompts" do
      %SystemPrompt{active: true}
      |> SystemPrompt.activate_changeset()
      |> refute_changes(:active)
    end
  end
end
