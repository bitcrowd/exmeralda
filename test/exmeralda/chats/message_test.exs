defmodule Exmeralda.Chats.MessageTest do
  use Exmeralda.DataCase

  alias Exmeralda.Chats.Message
  alias Exmeralda.Repo

  describe "table" do
    test "incomplete default to false" do
      session = insert(:chat_session)
      model_config = insert(:model_config)
      provider = insert(:provider)

      message =
        params_for(:message,
          session_id: session.id,
          model_config_id: model_config.id,
          provider_id: provider.id
        )
        |> Message.changeset()
        |> Repo.insert!()

      refute message.incomplete
    end

    test "restrict on deletion of provider or model config" do
      session = insert(:chat_session)
      model_config = insert(:model_config)
      provider = insert(:provider)

      insert(:message,
        session: session,
        model_config: model_config,
        provider: provider
      )

      assert_raise Ecto.ConstraintError, ~r/chat_messages_provider_id_fkey/, fn ->
        Repo.delete(provider)
      end

      assert_raise Ecto.ConstraintError, ~r/chat_messages_model_config_id_fkey/, fn ->
        Repo.delete(model_config)
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
      |> assert_required_error_on(:model_config_id)
      |> assert_required_error_on(:provider_id)
    end

    test "is valid with valid params" do
      params =
        params_for(:message, session_id: uuid(), model_config_id: uuid(), provider_id: uuid())

      %Message{}
      |> Message.changeset(params)
      |> assert_changeset_valid()
      |> assert_changes(:role, params.role)
      |> assert_changes(:index, params.index)
      |> assert_changes(:content, params.content)
      |> assert_changes(:session_id, params.session_id)
      |> assert_changes(:model_config_id, params.model_config_id)
      |> assert_changes(:provider_id, params.provider_id)
    end
  end
end
