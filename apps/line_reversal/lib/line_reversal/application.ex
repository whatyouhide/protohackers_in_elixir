defmodule LineReversal.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {Registry, name: LineReversal.Registry, keys: :unique},
      {LineReversal.Acceptor,
       port: String.to_integer(System.get_env("UDP_PORT", "5008")), ip: udp_ip_address()}
    ]

    opts = [strategy: :one_for_one, name: LineReversal.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp udp_ip_address do
    case System.fetch_env("FLY_APP_NAME") do
      {:ok, _} ->
        {:ok, fly_global_ip} = :inet.getaddr(~c"fly-global-services", :inet)
        fly_global_ip

      :error ->
        {0, 0, 0, 0}
    end
  end
end
