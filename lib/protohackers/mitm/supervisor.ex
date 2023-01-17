defmodule Protohackers.MITM.Supervisor do
  use Supervisor

  @spec start_link(keyword()) :: Supervisor.on_start()
  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts)
  end

  @impl true
  def init(opts) do
    children = [
      {Protohackers.MITM.ConnectionSupervisor, []},
      {Protohackers.MITM.Acceptor, opts}
    ]

    Supervisor.init(children, strategy: :rest_for_one)
  end
end
