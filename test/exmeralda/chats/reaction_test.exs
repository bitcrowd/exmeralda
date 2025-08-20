defmodule Exmeralda.Chats.ReactionTest do
  use Exmeralda.DataCase
  alias Exmeralda.Repo

  describe "table" do
    test "unique reaction by message and user" do
      user = insert(:user)
      message = insert(:message)

      insert(:reaction, message: message, user: user, type: :upvote)

      assert_raise Ecto.ConstraintError, ~r/chat_reactions_message_id_user_id_index/, fn ->
        insert(:reaction, message: message, user: user, type: :upvote)
      end
    end
  end

  describe "nilify behaviour" do
    setup do
      user = insert(:user)
      ingestion = insert(:ingestion)
      chat_session = insert(:chat_session, user: user, ingestion: ingestion)
      message = insert(:message, session: chat_session)

      reaction = insert(:reaction, message: message, user: user, type: :upvote)

      %{user: user, chat_session: chat_session, message: message, reaction: reaction}
    end

    test "user is nilified on deletion of the user", %{
      user: user,
      chat_session: chat_session,
      message: message,
      reaction: reaction
    } do
      Repo.delete(user)

      assert Repo.reload(chat_session)
      assert Repo.reload(message)

      reaction = Repo.reload(reaction)
      assert reaction.message_id
      refute reaction.user_id
    end
  end
end
