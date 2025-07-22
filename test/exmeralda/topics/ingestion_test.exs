defmodule Exmeralda.Topics.IngestionTest do
  use Exmeralda.DataCase

  import BitcrowdEcto.Random

  alias Exmeralda.Topics.Ingestion

  describe "changeset/2" do
    test "works" do
      changeset = Ingestion.changeset(%{state: :queued, library_id: uuid()})

      assert changeset.valid?
    end
  end
end
