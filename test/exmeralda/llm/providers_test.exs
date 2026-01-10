defmodule Exmeralda.LLM.ProvidersTest do
  use Exmeralda.DataCase
  alias Exmeralda.LLM.{Providers, Provider}
  alias Exmeralda.Repo

  describe "list_providers/1" do
    test "returns the lists of system prompts ordered by creation date" do
      deletable_provider =
        insert(:provider, inserted_at: ~U[2022-09-10 08:27:53.023055Z])

      non_deletable_provider =
        insert(:provider, inserted_at: ~U[2022-08-10 08:27:53.023055Z])

      # Two model config providers and three generation environments to check
      # that the left_join doesn't cause duplicated rows
      mcp_a = insert(:model_config_provider, provider: non_deletable_provider)
      mcp_b = insert(:model_config_provider, provider: non_deletable_provider)

      insert(:generation_environment, model_config_provider: mcp_a)
      insert(:generation_environment, model_config_provider: mcp_a)
      insert(:generation_environment, model_config_provider: mcp_b)

      assert {:ok, {[provider_a, provider_b], _meta}} =
               Providers.list_providers(%{})

      assert provider_a.id == deletable_provider.id
      assert provider_a.deletable

      assert provider_b.id == non_deletable_provider.id
      refute provider_b.deletable
    end
  end

  describe "create_provider/1" do
    test "with valid data creates a provider" do
      valid_attrs = %{type: :ollama, name: "ollama"}

      assert {:ok, %Provider{type: :ollama, name: "ollama"}} =
               Providers.create_provider(valid_attrs)
    end

    test "create_provider/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Providers.create_provider(%{})
    end
  end

  describe "delete_provider/1 when the provider does not exist" do
    test "returns ok" do
      assert Providers.delete_provider(uuid()) == :ok
    end
  end

  describe "delete_provider/1 when the provider is used" do
    test "returns an error" do
      provider = insert(:provider)
      mcp = insert(:model_config_provider, provider: provider)
      insert(:generation_environment, model_config_provider: mcp)

      assert Providers.delete_provider(provider.id) == {:error, :provider_used}
    end
  end

  describe "delete_provider/" do
    test "deletes the provider" do
      provider = insert(:provider)
      assert Providers.delete_provider(provider.id) == :ok
      refute Repo.reload(provider)
    end
  end
end
