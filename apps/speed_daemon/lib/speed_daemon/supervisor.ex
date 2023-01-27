defmodule SpeedDaemon.Supervisor do
  use Supervisor

  @spec start_link(keyword()) :: Supervisor.on_start()
  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts)
  end

  @impl true
  def init(opts) do
    registry_opts = [
      name: SpeedDaemon.DispatchersRegistry,
      keys: :duplicate,
      listeners: [SpeedDaemon.CentralTicketDispatcher]
    ]

    children = [
      {Registry, registry_opts},
      {SpeedDaemon.CentralTicketDispatcher, []},
      {SpeedDaemon.ConnectionSupervisor, []},
      {SpeedDaemon.Acceptor, opts}
    ]

    Supervisor.init(children, strategy: :rest_for_one)
  end
end
