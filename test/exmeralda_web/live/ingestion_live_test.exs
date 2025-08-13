defmodule ExmeraldaWeb.IngestionLiveTest do
  use ExmeraldaWeb.ConnCase

  import Phoenix.LiveViewTest

  defp insert_library(_) do
    library = insert(:library, name: "ecto")
    ingestion = insert(:ingestion, library: library, state: :ready)

    rag_library = insert(:library, name: "rag")
    _rag_ingestion = insert(:ingestion, library: rag_library, state: :embedding)

    %{library: library, ingestion: ingestion}
  end

  defp insert_user(_) do
    %{user: insert(:user)}
  end

  describe "Index" do
    setup [:insert_library, :insert_user]

    test "shows current ingestions", %{conn: conn, user: user} do
      {:ok, _index_live, html} =
        conn
        |> log_in_user(user)
        |> live(~p"/ingestions")

      assert html =~ "Ingestions"

      assert html =~ "rag"
      assert html =~ "embedding"
    end

    test "requires authentication", %{conn: conn} do
      assert {:error,
              {:redirect, %{to: "/", flash: %{"error" => "You must log in to access this page."}}}} =
               live(conn, ~p"/ingestions")
    end
  end
end
