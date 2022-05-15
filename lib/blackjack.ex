defmodule Blackjack do
  use Application

  def start(_type, _args) do
    children = [
      {Registry, [keys: :unique, name: Blackjack.Registry]},
      {DynamicSupervisor, strategy: :one_for_one, name: Blackjack.RoundsDynamicSup}
    ]

    Supervisor.start_link(children, strategy: :rest_for_one)
  end

  def service_name(service_id), do: {:via, Registry, {Blackjack.Registry, service_id}}
end
