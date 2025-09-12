defmodule Exmeralda.Topics.GenerationPromptTest do
  use Exmeralda.DataCase
  alias Exmeralda.Topics.GenerationPrompt

  describe "changeset/1" do
    test "is invalid for invalid attrs" do
      %{}
      |> GenerationPrompt.changeset()
      |> refute_changeset_valid()
      |> assert_required_error_on(:prompt)
    end

    test "returns a changeset" do
      %{prompt: "You are a duck"}
      |> GenerationPrompt.changeset()
      |> assert_changeset_valid()
      |> assert_changes(:prompt, "You are a duck")
    end
  end
end
