defmodule Exmeralda.Topics.IngestionTest do
  use Exmeralda.DataCase

  import BitcrowdEcto.Random
  import Ecto.Changeset

  alias Exmeralda.Topics.Ingestion

  describe "changeset/2" do
    test "works" do
      changeset = Ingestion.changeset(%{state: :queued, library_id: uuid()})

      assert changeset.valid?
    end
  end

  describe "set_state/2" do
    test "sets state of ingestion" do
      ingestion = %Ingestion{library_id: uuid(), state: :queued}

      changeset = Ingestion.set_state(ingestion, :ready)

      assert changeset.valid?
      assert get_change(changeset, :state) == :ready
    end
  end
end
