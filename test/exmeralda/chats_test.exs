defmodule Exmeralda.ChatsTest do
  use Exmeralda.DataCase

  alias Exmeralda.Chats

  defp create_user_and_session(_context) do
    user = insert(:user)
    session = insert(:chat_session, user: user)

    %{user: user, session: session}
  end

  defp create_message(%{session: session}) do
    message = insert(:message, session: session)

    %{message: message}
  end

  describe "create_reaction/3" do
    setup [:create_user_and_session, :create_message]

    test "creates new reaction for message and user", %{message: message, user: user} do
      assert {:ok, _reaction} = Chats.create_reaction(message, user, :upvote)
    end
  end
end
