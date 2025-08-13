defmodule Exmeralda.Chats.SessionTest do
  use Exmeralda.DataCase

  alias Exmeralda.Chats.Session

  describe "create_changeset/2" do
    test "errors with invalid params" do
      %Session{}
      |> Session.create_changeset(%{})
      |> refute_changeset_valid()
      |> assert_required_error_on(:ingestion_id)
      |> assert_required_error_on(:prompt)
    end

    test "is valid and sets the title with valid params" do
      params = %{ingestion_id: uuid(), prompt: "foo"}

      %Session{}
      |> Session.create_changeset(params)
      |> assert_changeset_valid()
      |> assert_changes(:ingestion_id, params.ingestion_id)
      |> assert_changes(:title, "foo")
    end

    test "slices the prompt to 255 characters" do
      prompt = String.duplicate("a", 256)
      sliced_prompt = String.duplicate("a", 255)
      params = %{ingestion_id: uuid(), prompt: prompt}

      %Session{}
      |> Session.create_changeset(params)
      |> assert_changeset_valid()
      |> assert_changes(:ingestion_id, params.ingestion_id)
      |> assert_changes(:title, sliced_prompt)
    end
  end
end
