defmodule Exmeralda.Chats.GenerationEnvironmentTest do
  use Exmeralda.DataCase

  describe "table" do
    test "unique by model_config_provider" do
      model_config_provider = insert(:model_config_provider)
      insert(:generation_environment, model_config_provider: model_config_provider)

      assert_raise Ecto.ConstraintError,
                   ~r/generation_environments_model_config_provider_id_index/,
                   fn ->
                     insert(:generation_environment, model_config_provider: model_config_provider)
                   end
    end
  end
end
