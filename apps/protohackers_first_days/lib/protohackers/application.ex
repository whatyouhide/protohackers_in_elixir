defmodule Protohackers.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {Protohackers.EchoServer, port: 5001},
      {Protohackers.PrimeServer, port: 5002},
      {Protohackers.PricesServer, port: 5003},
      {Protohackers.BudgetChatServer, port: 5004},
      {Protohackers.UDPServer, port: 5005},
      {Protohackers.MITM.Supervisor, port: 5006},
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Protohackers.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
