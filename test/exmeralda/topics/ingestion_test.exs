defmodule Exmeralda.Topics.IngestionTest do
  use Exmeralda.DataCase
  alias Exmeralda.Topics.Ingestion

  describe "table" do
    test "active_when_ready constraint" do
      insert(:ingestion, active: true, state: :ready)
      insert(:ingestion, active: false, state: :ready)
      insert(:ingestion, active: false, state: :queued)

      assert_raise Ecto.ConstraintError, ~r/active_when_ready/, fn ->
        insert(:ingestion, active: true, state: :queued)
      end
    end
  end

  describe "changeset/2" do
    test "works" do
      %{state: :queued, library_id: uuid()}
      |> Ingestion.changeset()
      |> assert_changeset_valid()
    end
  end

  describe "set_state/2" do
    for {from, to} <- [
          {:queued, :embedding},
          {:embedding, :ready},
          {:queued, :failed},
          {:embedding, :failed}
        ] do
      test "sets state of ingestion from #{from} to #{to}" do
        build(:ingestion, state: unquote(from))
        |> Ingestion.set_state(unquote(to))
        |> assert_changeset_valid()
        |> assert_changes(:state, unquote(to))
      end
    end

    test "errors for invalid transitions" do
      build(:ingestion, state: :ready)
      |> Ingestion.set_state(:queued)
      |> refute_changeset_valid()
    end
  end

  describe "set_ingestion_inactive_changeset/1" do
    test "sets active to false" do
      build(:ingestion, active: true)
      |> Ingestion.set_ingestion_inactive_changeset()
      |> assert_changeset_valid()
      |> assert_changes(:active, false)
    end
  end

  describe "set_ingestion_active_changeset/1" do
    test "sets active to true" do
      build(:ingestion, active: false)
      |> Ingestion.set_ingestion_active_changeset()
      |> assert_changeset_valid()
      |> assert_changes(:active, true)
    end
  end
end
