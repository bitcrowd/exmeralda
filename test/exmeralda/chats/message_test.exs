defmodule Exmeralda.Chats.MessageTest do
  use Exmeralda.DataCase

  alias Exmeralda.Chats.Message
  alias Exmeralda.Repo

  describe "table" do
    test "incomplete default to false" do
      session = insert(:chat_session)
      generation_environment = insert(:generation_environment)

      message =
        params_for(:message,
          session_id: session.id,
          generation_environment_id: generation_environment.id
        )
        |> Message.changeset()
        |> Repo.insert!()

      refute message.incomplete
    end

    test "restrict on deletion of generation environment" do
      session = insert(:chat_session)
      generation_environment = insert(:generation_environment)

      insert(:message,
        session: session,
        generation_environment: generation_environment
      )

      assert_raise Ecto.ConstraintError, ~r/chat_messages_generation_environment_id_fkey/, fn ->
        Repo.delete(generation_environment)
      end
    end
  end

  describe "changeset/2" do
    test "errors with invalid params" do
      %Message{}
      |> Message.changeset(%{})
      |> refute_changeset_valid()
      |> assert_required_error_on(:role)
      |> assert_required_error_on(:index)
      |> assert_required_error_on(:content)
      |> assert_required_error_on(:session_id)
      |> assert_required_error_on(:generation_environment_id)
    end

    test "is valid with valid params" do
      params =
        params_for(:message, session_id: uuid(), generation_environment_id: uuid())

      %Message{}
      |> Message.changeset(params)
      |> assert_changeset_valid()
      |> assert_changes(:role, params.role)
      |> assert_changes(:index, params.index)
      |> assert_changes(:content, params.content)
      |> assert_changes(:session_id, params.session_id)
      |> assert_changes(:generation_environment_id, params.generation_environment_id)
    end
  end
end
