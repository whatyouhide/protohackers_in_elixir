defmodule SpeedDaemon.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    port = String.to_integer(System.get_env("TCP_PORT", "5007"))

    children = [
      {SpeedDaemon.Supervisor, port: port}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: SpeedDaemon.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
