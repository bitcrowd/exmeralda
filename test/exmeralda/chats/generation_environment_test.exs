defmodule Exmeralda.Chats.GenerationEnvironmentTest do
  use Exmeralda.DataCase

  describe "table" do
    test "unique by model_config_provider, system prompt and generation prompt" do
      model_config_provider = insert(:model_config_provider)
      system_prompt = insert(:system_prompt)
      generation_prompt = insert(:generation_prompt)

      insert(:generation_environment,
        model_config_provider: model_config_provider,
        system_prompt: system_prompt,
        generation_prompt: generation_prompt
      )

      assert_raise Ecto.ConstraintError,
                   ~r/generation_environments_unique/,
                   fn ->
                     insert(:generation_environment,
                       model_config_provider: model_config_provider,
                       system_prompt: system_prompt,
                       generation_prompt: generation_prompt
                     )
                   end
    end

    test "restrict on deletion of provider or model config" do
      model_config = insert(:model_config)
      provider = insert(:provider)

      model_config_provider =
        insert(:model_config_provider, model_config: model_config, provider: provider)

      insert(:generation_environment, model_config_provider: model_config_provider)

      assert_raise Ecto.ConstraintError,
                   ~r/generation_environments_model_config_provider_id_fkey/,
                   fn ->
                     Repo.delete(provider)
                   end

      assert_raise Ecto.ConstraintError,
                   ~r/generation_environments_model_config_provider_id_fkey/,
                   fn ->
                     Repo.delete(model_config)
                   end

      assert_raise Ecto.ConstraintError,
                   ~r/generation_environments_model_config_provider_id_fkey/,
                   fn ->
                     Repo.delete(model_config_provider)
                   end
    end
  end
end
