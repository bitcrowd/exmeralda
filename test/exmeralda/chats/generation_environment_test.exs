defmodule Exmeralda.Chats.GenerationEnvironmentTest do
  use Exmeralda.DataCase

  describe "table" do
    test "unique by model_config_provider" do
      model_config_provider = insert(:model_config_provider)
      system_prompt = insert(:system_prompt)

      insert(:generation_environment,
        model_config_provider: model_config_provider,
        system_prompt: system_prompt
      )

      assert_raise Ecto.ConstraintError,
                   ~r/generation_environments_model_config_provider_id_system_prompt/,
                   fn ->
                     insert(:generation_environment,
                       model_config_provider: model_config_provider,
                       system_prompt: system_prompt
                     )
                   end
    end
  end
end
