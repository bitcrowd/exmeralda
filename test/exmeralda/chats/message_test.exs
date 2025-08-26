defmodule Exmeralda.Chats.MessageTest do
  use Exmeralda.DataCase

  alias Exmeralda.Chats.Message
  alias Exmeralda.Repo

  describe "table" do
    test "incomplete default to false" do
      session = insert(:chat_session)
      generation_config = insert(:generation_config)

      message =
        params_for(:message, session_id: session.id, generation_config_id: generation_config.id)
        |> Message.changeset()
        |> Repo.insert!()

      refute message.incomplete
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
      |> assert_required_error_on(:generation_config_id)
    end

    test "is valid with valid params" do
      params = params_for(:message, session_id: uuid(), generation_config_id: uuid())

      %Message{}
      |> Message.changeset(params)
      |> assert_changeset_valid()
      |> assert_changes(:role, params.role)
      |> assert_changes(:index, params.index)
      |> assert_changes(:content, params.content)
      |> assert_changes(:session_id, params.session_id)
      |> assert_changes(:generation_config_id, params.generation_config_id)
    end
  end
end
