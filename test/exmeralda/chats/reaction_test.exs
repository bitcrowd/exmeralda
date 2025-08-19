defmodule Exmeralda.Chats.ReactionTest do
  use Exmeralda.DataCase
  alias Exmeralda.Chats.Reaction
  alias Exmeralda.Repo

  describe "table" do
    test "unique reaction by message and user" do
      user = insert(:user)
      message = insert(:message)
      ingestion = insert(:ingestion)

      insert(:reaction, ingestion: ingestion, message: message, user: user, type: :upvote)

      assert_raise Ecto.ConstraintError, ~r/chat_reactions_message_id_user_id_index/, fn ->
        insert(:reaction, ingestion: ingestion, message: message, user: user, type: :upvote)
      end
    end
  end

  describe "nilify behaviour" do
    setup do
      user = insert(:user)
      ingestion = insert(:ingestion)
      chat_session = insert(:chat_session, user: user, ingestion: ingestion)
      message = insert(:message, session: chat_session)

      reaction =
        insert(:reaction, ingestion: ingestion, message: message, user: user, type: :upvote)

      %{user: user, chat_session: chat_session, message: message, reaction: reaction}
    end

    test "message is nilified on deletion of the chat session", %{
      chat_session: chat_session,
      message: message,
      reaction: reaction
    } do
      Repo.delete(chat_session)

      refute Repo.reload(chat_session)
      refute Repo.reload(message)

      reaction = Repo.reload(reaction)
      refute reaction.message_id
      assert reaction.user_id
      assert reaction.ingestion_id
    end

    test "user is nilified on deletion of the user", %{
      user: user,
      chat_session: chat_session,
      message: message,
      reaction: reaction
    } do
      Repo.delete(user)

      refute Repo.reload(chat_session)
      refute Repo.reload(message)

      reaction = Repo.reload(reaction)
      refute reaction.message_id
      refute reaction.user_id
      assert reaction.ingestion_id
    end
  end

  describe "changeset/2" do
    test "is valid with valid params" do
      %{user_id: uuid(), message_id: uuid(), ingestion_id: uuid(), type: :upvote}
      |> Reaction.changeset()
      |> assert_changeset_valid()
    end

    test "is invalid with invalid params" do
      %{}
      |> Reaction.changeset()
      |> refute_changeset_valid()
      |> assert_required_error_on(:ingestion_id)
      |> assert_required_error_on(:message_id)
      |> assert_required_error_on(:type)
      |> assert_required_error_on(:user_id)
    end
  end
end
