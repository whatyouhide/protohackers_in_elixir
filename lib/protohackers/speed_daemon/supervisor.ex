defmodule Protohackers.SpeedDaemon.Supervisor do
  use Supervisor

  @spec start_link(keyword()) :: Supervisor.on_start()
  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts)
  end

  @impl true
  def init(opts) do
    registry_opts = [
      name: Protohackers.SpeedDaemon.DispatchersRegistry,
      keys: :duplicate,
      listeners: [Protohackers.SpeedDaemon.CentralTicketDispatcher]
    ]

    children = [
      {Registry, registry_opts},
      {Protohackers.SpeedDaemon.CentralTicketDispatcher, []},
      {Protohackers.SpeedDaemon.ConnectionSupervisor, []},
      {Protohackers.SpeedDaemon.Acceptor, opts}
    ]

    Supervisor.init(children, strategy: :rest_for_one)
  end
end
