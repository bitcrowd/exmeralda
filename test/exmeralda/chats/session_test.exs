defmodule Exmeralda.Chats.SessionTest do
  use Exmeralda.DataCase

  alias Exmeralda.Chats.Session

  describe "table" do
    setup do
      # original session
      user = insert(:user)

      chat_session =
        insert(:chat_session, user: user, original_session: nil, copied_from_message: nil)

      message = insert(:message, session: chat_session)

      %{user: user, chat_session: chat_session, message: message}
    end

    test "original_session_when_copied_from_message constraint", %{
      user: user,
      chat_session: chat_session,
      message: message
    } do
      # Works
      insert(:chat_session, user: user, original_session: nil, copied_from_message: nil)

      insert(:chat_session,
        user: nil,
        original_session: chat_session,
        copied_from_message: message
      )

      assert_raise Ecto.ConstraintError, ~r/original_session_when_copied_from_message/, fn ->
        insert(:chat_session, user: nil, original_session: chat_session, copied_from_message: nil)
      end

      assert_raise Ecto.ConstraintError, ~r/original_session_when_copied_from_message/, fn ->
        insert(:chat_session, user: nil, original_session: nil, copied_from_message: message)
      end
    end

    test "used_id_null_when_regeneration_fields constraint", %{
      user: user,
      chat_session: chat_session,
      message: message
    } do
      # Works
      insert(:chat_session,
        user: nil,
        original_session: chat_session,
        copied_from_message: message
      )

      assert_raise Ecto.ConstraintError, ~r/used_id_null_when_regeneration_fields/, fn ->
        insert(:chat_session,
          user: user,
          original_session: chat_session,
          copied_from_message: message
        )
      end
    end
  end

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

  describe "nilify behaviour" do
    setup do
      user = insert(:user)
      ingestion = insert(:ingestion)
      chat_session = insert(:chat_session, user: user, ingestion: ingestion)
      message = insert(:message, session: chat_session)
      reaction = insert(:reaction, message: message)

      %{user: user, chat_session: chat_session, message: message, reaction: reaction}
    end

    test "user is nilified on deletion of the user", %{
      user: user,
      chat_session: chat_session,
      message: message,
      reaction: reaction
    } do
      Repo.delete(user)

      chat_session = Repo.reload(chat_session)
      assert chat_session
      refute chat_session.user_id

      assert Repo.reload(message)
      assert Repo.reload(reaction)
    end
  end
end
