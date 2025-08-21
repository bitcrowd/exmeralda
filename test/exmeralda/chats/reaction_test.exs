defmodule Exmeralda.Chats.ReactionTest do
  use Exmeralda.DataCase

  describe "table" do
    test "unique reaction by message" do
      message = insert(:message)

      insert(:reaction, message: message, type: :upvote)

      assert_raise Ecto.ConstraintError, ~r/chat_reactions_message_id_index/, fn ->
        insert(:reaction, message: message, type: :upvote)
      end
    end
  end
end
