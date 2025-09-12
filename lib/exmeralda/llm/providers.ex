defmodule Exmeralda.LLM.Providers do
  @moduledoc """
  The Providers context.
  """

  import Ecto.Query, warn: false
  alias Exmeralda.Repo
  alias Exmeralda.LLM.{ModelConfigProvider, Provider}
  alias Exmeralda.Chats.GenerationEnvironment

  @spec list_providers(map()) ::
          {:ok, {[Provider.t()], Flop.Meta.t()}} | {:error, Flop.Meta.t()}
  def list_providers(params) do
    subquery =
      from(ge in GenerationEnvironment,
        left_join: mcp in ModelConfigProvider,
        on: ge.model_config_provider_id == mcp.id,
        distinct: mcp.provider_id,
        select: %{ge_id: ge.id, provider_id: mcp.provider_id}
      )

    from(p in Provider,
      left_join: s in subquery(subquery),
      on: s.provider_id == p.id,
      select: %{p | deletable: is_nil(s.ge_id)}
    )
    |> Flop.validate_and_run(params, for: Provider)
  end

  @spec create_provider(map()) ::
          {:ok, Provider.t()} | {:error, Ecto.Changeset.t()}
  def create_provider(attrs \\ %{}) do
    attrs
    |> Provider.changeset()
    |> Repo.insert()
  end

  @spec delete_provider(SystemPrompt.id()) :: :ok | {:error, :provider_used}
  def delete_provider(provider_id) do
    provider = Repo.get(Provider, provider_id)

    cond do
      Repo.exists?(
        from(ge in GenerationEnvironment,
          join: mcp in ModelConfigProvider,
          on: ge.model_config_provider_id == mcp.id,
          where: mcp.provider_id == ^provider_id
        )
      ) ->
        {:error, :provider_used}

      not is_nil(provider) ->
        Repo.delete(provider, allow_stale: true)
        :ok

      true ->
        :ok
    end
  end

  def change_provider do
    Ecto.Changeset.change(%Provider{})
  end
end
