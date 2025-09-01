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

    test "restrict on deletion of provider or model config" do
      session = insert(:chat_session)
      model_config = insert(:model_config)
      provider = insert(:provider)

      model_config_provider =
        insert(:model_config_provider, model_config: model_config, provider: provider)

      generation_environment =
        insert(:generation_environment, model_config_provider: model_config_provider)

      insert(:message,
        session: session,
        generation_environment: generation_environment
      )

      assert_raise Ecto.ConstraintError, ~r/chat_messages_generation_environment_id_fkey/, fn ->
        Repo.delete(provider)
      end

      assert_raise Ecto.ConstraintError, ~r/chat_messages_generation_environment_id_fkey/, fn ->
        Repo.delete(model_config)
      end

      assert_raise Ecto.ConstraintError, ~r/chat_messages_generation_environment_id_fkey/, fn ->
        Repo.delete(model_config_provider)
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

  describe "duplicate_changeset/2" do
    test "errors with invalid params" do
      %Message{}
      |> Message.duplicate_changeset(%{})
      |> refute_changeset_valid()
      |> assert_required_error_on(:role)
      |> assert_required_error_on(:index)
      |> assert_required_error_on(:content)
    end

    test "is valid with valid params" do
      chunk_id = uuid()

      params =
        params_for(:message,
          generation_environment_id: uuid(),
          incomplete: true,
          sources: [
            %{chunk_id: chunk_id}
          ]
        )

      changeset =
        %Message{}
        |> Message.duplicate_changeset(params)
        |> assert_changeset_valid()
        |> assert_changes(:role, params.role)
        |> assert_changes(:index, params.index)
        |> assert_changes(:content, params.content)
        |> assert_changes(:incomplete, params.incomplete)
        |> assert_changes(:generation_environment_id, params.generation_environment_id)

      assert [source_cs] = changeset.changes.sources
      assert_changes(source_cs, :chunk_id, chunk_id)
    end
  end
end
