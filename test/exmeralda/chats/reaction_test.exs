defmodule Exmeralda.Chats.ReactionTest do
  use Exmeralda.DataCase

  import BitcrowdEcto.Random

  alias Exmeralda.Chats.Reaction

  describe "changeset/2" do
    test "is valid with valid params" do
      params = %{"user_id" => uuid(), "message_id" => uuid(), "type" => "upvote"}

      changeset = Reaction.changeset(params)

      assert changeset.valid?
    end

    test "validates unique reaction by message and user" do
      user = insert(:user)
      session = insert(:chat_session, user: user)
      message = insert(:message, session: session)
      reation = insert(:reaction, message: message, user: user, type: :upvote)

      params = %{"user_id" => user.id, "message_id" => message.id, "type" => "downvote"}

      changeset = Reaction.changeset(params)

      refute changeset.valid?
    end
  end
end
