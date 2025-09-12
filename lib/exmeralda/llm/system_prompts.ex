defmodule Exmeralda.LLM.SystemPrompts do
  @moduledoc """
  The SystemPrompts context.
  """

  import Ecto.Query
  alias Exmeralda.Repo
  alias Exmeralda.LLM.SystemPrompt
  alias Exmeralda.Chats.GenerationEnvironment

  @doc """
  Returns the list of system_prompts.
  """
  def list_system_prompts(params) do
    from(s in SystemPrompt,
      left_join: ge in subquery(from(ge in GenerationEnvironment, distinct: ge.system_prompt_id)),
      on: ge.system_prompt_id == s.id,
      select: %{s | deletable: is_nil(ge.id)}
    )
    |> Flop.validate_and_run(params, for: SystemPrompt)
  end

  @spec create_system_prompt(map()) :: {:ok, SystemPrompt.t()} | {:error, Ecto.Changeset.t()}
  def create_system_prompt(attrs \\ %{}) do
    attrs
    |> SystemPrompt.changeset()
    |> Repo.insert()
  end

  @spec delete_system_prompt(SystemPrompt.id()) :: :ok | {:error, :system_prompt_used}
  def delete_system_prompt(system_prompt_id) do
    system_prompt = Repo.get(SystemPrompt, system_prompt_id)

    cond do
      Repo.exists?(
        from(ge in GenerationEnvironment, where: ge.system_prompt_id == ^system_prompt_id)
      ) ->
        {:error, :system_prompt_used}

      not is_nil(system_prompt) ->
        Repo.delete(system_prompt, allow_stale: true)
        :ok

      true ->
        :ok
    end
  end

  def change_system_prompt do
    Ecto.Changeset.change(%SystemPrompt{})
  end
end
