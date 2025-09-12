defmodule Exmeralda.Topics.GenerationPrompts do
  @moduledoc """
  The GenerationPrompts context.
  """

  import Ecto.Query, warn: false
  alias Exmeralda.Repo
  alias Exmeralda.Topics.GenerationPrompt
  alias Exmeralda.Chats.GenerationEnvironment

  @spec list_generation_prompts(map()) ::
          {:ok, {[GenerationPrompt.t()], Flop.Meta.t()}} | {:error, Flop.Meta.t()}
  def list_generation_prompts(params) do
    from(s in GenerationPrompt,
      left_join:
        ge in subquery(from(ge in GenerationEnvironment, distinct: ge.generation_prompt_id)),
      on: ge.generation_prompt_id == s.id,
      select: %{s | deletable: is_nil(ge.id)}
    )
    |> Flop.validate_and_run(params, for: GenerationPrompt)
  end

  @spec create_generation_prompt(map()) ::
          {:ok, GenerationPrompt.t()} | {:error, Ecto.Changeset.t()}
  def create_generation_prompt(attrs \\ %{}) do
    attrs
    |> GenerationPrompt.changeset()
    |> Repo.insert()
  end

  @spec delete_generation_prompt(SystemPrompt.id()) :: :ok | {:error, :generation_prompt_used}
  def delete_generation_prompt(generation_prompt_id) do
    generation_prompt = Repo.get(GenerationPrompt, generation_prompt_id)

    cond do
      Repo.exists?(
        from(ge in GenerationEnvironment, where: ge.generation_prompt_id == ^generation_prompt_id)
      ) ->
        {:error, :generation_prompt_used}

      not is_nil(generation_prompt) ->
        Repo.delete(generation_prompt, allow_stale: true)
        :ok

      true ->
        :ok
    end
  end

  def change_generation_prompt do
    Ecto.Changeset.change(%GenerationPrompt{})
  end
end
