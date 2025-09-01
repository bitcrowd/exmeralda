defmodule Exmeralda.Chats.SourceTest do
  use Exmeralda.DataCase
  alias Exmeralda.Chats.Source

  describe "duplicate_changeset/2" do
    test "errors with invalid params" do
      %Source{}
      |> Source.duplicate_changeset(%{})
      |> refute_changeset_valid()
      |> assert_required_error_on(:chunk_id)
    end

    test "is valid with valid params" do
      params = %{chunk_id: uuid()}

      %Source{}
      |> Source.duplicate_changeset(params)
      |> assert_changeset_valid()
      |> assert_changes(:chunk_id, params.chunk_id)
    end
  end
end
