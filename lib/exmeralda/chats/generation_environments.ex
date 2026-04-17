defmodule Exmeralda.Chats.GenerationEnvironments do
  @moduledoc """
  The GenerationEnvironments context.
  """

  import Ecto.Query
  alias Exmeralda.Repo
  alias Exmeralda.Chats.GenerationEnvironment
  alias Exmeralda.LLM.SystemPrompts

  @preloads [
    :system_prompt,
    :generation_prompt,
    model_config_provider: [:provider, :model_config]
  ]

  @doc """
  Returns the list of generation_environments.
  """
  def list_generation_environments(params) do
    GenerationEnvironment
    |> preload(^@preloads)
    |> Flop.validate_and_run(params, for: GenerationEnvironment)
  end

  @doc """
  Gets a single generation_environment.
  """
  def get_generation_environment!(id) do
    GenerationEnvironment
    |> preload(^@preloads)
    |> Repo.get!(id)
  end

  @doc """
  Returns the ID of the current generation environment.
  """
  @spec get_current_generation_environment_id() :: Ecto.UUID.t() | nil
  def get_current_generation_environment_id do
    %{model_config_provider_id: mcp_id, generation_prompt_id: gp_id} =
      Application.fetch_env!(:exmeralda, :llm_config)

    case SystemPrompts.get_current_system_prompt() do
      %{id: sp_id} ->
        Repo.one(
          from ge in GenerationEnvironment,
            where: ge.model_config_provider_id == ^mcp_id,
            where: ge.system_prompt_id == ^sp_id,
            where: ge.generation_prompt_id == ^gp_id,
            select: ge.id
        )

      _ ->
        nil
    end
  end
end
