defmodule Exmeralda.Regenerations.Server do
  use GenServer
  require Logger
  alias Exmeralda.Regenerations
  alias Exmeralda.Repo
  alias Ecto.Multi

  def init(%{message_ids: message_ids, generation_environment_id: generation_environment_id}) do
    Phoenix.PubSub.subscribe(Exmeralda.PubSub, "regenerations")

    {:ok,
     %{
       completion: Map.new(message_ids, fn message_id -> {message_id, false} end),
       message_ids: message_ids,
       generation_environment_id: generation_environment_id
     }}
  end

  def handle_call(:regenerate, _from, state) do
    Enum.reduce(state.message_ids, Multi.new(), fn message_id, multi ->
      Multi.run(
        multi,
        {:message, message_id},
        fn _, _ -> Regenerations.regenerate(message_id, state.generation_environment_id) end
      )
    end)
    |> Repo.transaction()
    |> case do
      {:ok, result} -> {:reply, result, state}
      {:error, step, error, _} -> {:stop, {step, error}, state}
    end
  end

  def handle_info({:message_regenerated, message_id}, state) do
    completion = Map.replace!(state.completion, message_id, true)

    Logger.info("⌛️ Message #{message_id} regenerated!")

    if Enum.all?(Map.values(completion)) do
      {:stop, :normal, %{state | completion: completion}}
    else
      {:noreply, %{state | completion: completion}}
    end
  end
end
