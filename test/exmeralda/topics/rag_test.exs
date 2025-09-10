defmodule Exmeralda.Topics.RagTest do
  use Exmeralda.DataCase
  import Exmeralda.Topics.Rag
  alias Exmeralda.Topics.Chunk

  describe "build_generation/3" do
    test "raises if the generation environment is not found" do
      message = build(:message, generation_environment_id: uuid())

      assert_raise(Ecto.NoResultsError, fn ->
        build_generation(from(c in Chunk), message)
      end)
    end

    test "returns a generation and result" do
      library = insert(:library)
      ingestion = insert(:ingestion, library: library)

      %{id: chunk_id} =
        insert(:chunk,
          ingestion: ingestion,
          library: library,
          content: "The cookie jar does not exist"
        )

      generation_prompt = insert(:generation_prompt)

      generation_environment =
        insert(:generation_environment, generation_prompt: generation_prompt)

      message =
        insert(:message,
          generation_environment: generation_environment,
          content: "Where is the cookie jar?"
        )

      assert {[%{id: ^chunk_id}], %Rag.Generation{} = generation} =
               build_generation(from(c in Chunk), message)

      assert generation.query == "Where is the cookie jar?"
      assert generation.context == "The cookie jar does not exist"

      assert generation.prompt == """
             Context information is below.
             ---------------------
             The cookie jar does not exist
             ---------------------
             Given the context information and no prior knowledge, answer the query.
             Query: Where is the cookie jar?
             Answer:
             """

      assert %{
               fulltext_results: [%{id: ^chunk_id}],
               semantic_results: [%{id: ^chunk_id}],
               rrf_result: [%{id: ^chunk_id}]
             } =
               generation.retrieval_results
    end
  end
end
