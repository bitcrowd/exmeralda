defmodule Exmeralda.LLM.SystemPromptTest do
  use Exmeralda.DataCase
  alias Exmeralda.LLM.SystemPrompt

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
end
