defmodule ISL.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    port = String.to_integer(System.get_env("TCP_PORT", "5009"))

    children = [
      {ThousandIsland, port: port, handler_module: ISL.Connection}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Isl.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
