defmodule Exmeralda.Regenerations.Server do
  use GenServer
  require Logger
  alias Exmeralda.Regenerations

  def init(%{message_ids: message_ids, generation_environment_id: generation_environment_id}) do
    Phoenix.PubSub.subscribe(Exmeralda.PubSub, "regenerations")

    {:ok,
     %{
       message_ids: message_ids,
       generation_environment_id: generation_environment_id,
       regenerated_messages: %{},
       skipped_messages: %{}
     }}
  end

  def handle_call(:regenerate, _from, state) do
    state =
      Enum.reduce(state.message_ids, state, fn message_id, acc ->
        case Regenerations.regenerate(message_id, state.generation_environment_id) do
          {:ok, %{assistant_message: assistant_message}} ->
            regenerated_messages =
              Map.put(acc.regenerated_messages, message_id, %{
                assistant_message_id: assistant_message.id,
                incomplete: true
              })

            %{acc | regenerated_messages: regenerated_messages}

          {:error, error} ->
            skipped_messages = Map.put(acc.skipped_messages, message_id, error)
            %{acc | skipped_messages: skipped_messages}
        end
      end)

    {:reply, state, state}
  end

  def handle_info({:message_regenerated, message_id}, state) do
    case Map.get(state.regenerated_messages, message_id) do
      nil ->
        {:noreply, state}

      %{assistant_message_id: assistant_message_id} ->
        Logger.info("⌛️ Message #{message_id} regenerated!")

        regenerated_messages =
          Map.replace!(state.regenerated_messages, message_id, %{
            assistant_message_id: assistant_message_id,
            incomplete: false
          })

        if all_regenerated_messages_complete?(regenerated_messages) do
          Phoenix.PubSub.unsubscribe(Exmeralda.PubSub, "regenerations")
          {:stop, :normal, %{state | regenerated_messages: regenerated_messages}}
        else
          {:noreply, %{state | regenerated_messages: regenerated_messages}}
        end
    end
  end

  defp all_regenerated_messages_complete?(regenerated_messages) do
    regenerated_messages
    |> Map.values()
    |> Enum.all?(&(!&1.incomplete))
  end
end
