defmodule Blackjack.RoundServer do
  use GenServer
  alias Blackjack.{PlayerNotifier, Round}

  @type id :: any
  @type player :: %{id: Round.player_id(), callback_mod: module, callback_arg: callback_arg}
  @type callback_arg :: any

  @spec start_playing(id, [player]) :: DynamicSupervisor.on_start_child()
  def start_playing(round_id, players) do
    supervisor_spec = %{
      id: Supervisor,
      start: {
        Supervisor,
        :start_link,
        [
          [
            PlayerNotifier.child_spec(round_id, players),
            %{id: __MODULE__, start: {__MODULE__, :start_link, [round_id, players]}}
          ],
          [strategy: :one_for_all]
        ]
      }
    }

    DynamicSupervisor.start_child(Blackjack.RoundsDynamicSup, supervisor_spec)
  end

  @spec move(id, Round.player_id(), Round.move()) :: :ok
  def move(round_id, player_id, move),
    do: GenServer.call(service_name(round_id), {:move, player_id, move})

  @doc false
  def start_link(round_id, players),
    do:
      GenServer.start_link(
        __MODULE__,
        {round_id, Enum.map(players, & &1.id)},
        name: service_name(round_id)
      )

  @doc false
  def init({round_id, player_ids}),
    do:
      {:ok,
       player_ids
       |> Round.start()
       |> handle_round_result(%{round_id: round_id, round: nil})}

  @doc false
  def handle_call({:move, player_id, move}, _from, state),
    do:
      {:reply, :ok,
       state.round
       |> Round.move(player_id, move)
       |> handle_round_result(state)}

  defp service_name(round_id), do: Blackjack.service_name({__MODULE__, round_id})

  defp handle_round_result({instructions, round}, state),
    do: Enum.reduce(instructions, %{state | round: round}, &handle_instruction(&2, &1))

  defp handle_instruction(state, {:notify_player, player_id, instruction_payload}) do
    PlayerNotifier.publish(state.round_id, player_id, instruction_payload)
    state
  end
end
