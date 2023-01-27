defmodule Protohackers.UDPServer do
  use GenServer

  require Logger

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  defstruct [:socket, store: %{"version" => "Protohackers in Elixir 1.0"}]

  @impl true
  def init(opts) do
    port = Keyword.fetch!(opts, :port)

    address =
      case System.fetch_env("FLY_APP_NAME") do
        {:ok, _} ->
          {:ok, fly_global_ip} = :inet.getaddr(~c"fly-global-services", :inet)
          fly_global_ip

        :error ->
          {0, 0, 0, 0}
      end

    Logger.info("Started server on #{:inet.ntoa(address)}:#{port}")

    case :gen_udp.open(5005, [:binary, active: false, recbuf: 1000, ip: address]) do
      {:ok, socket} ->
        state = %__MODULE__{socket: socket}
        {:ok, state, {:continue, :recv}}

      {:error, reason} ->
        {:stop, reason}
    end
  end

  @impl true
  def handle_continue(:recv, %__MODULE__{} = state) do
    case :gen_udp.recv(state.socket, 0) do
      {:ok, {address, port, packet}} ->
        Logger.debug(
          "Received UDP packet from #{inspect(address)}:#{inspect(port)}: #{inspect(packet)}"
        )

        state =
          case String.split(packet, "=", parts: 2) do
            # Don't do anything for the "version" key.
            ["version", _value] ->
              state

            [key, value] ->
              Logger.debug("Inserted key #{inspect(key)} with value #{inspect(value)}")
              put_in(state.store[key], value)

            [key] ->
              Logger.debug("Requested key: #{inspect(key)}")
              packet = "#{key}=#{state.store[key]}"
              :gen_udp.send(state.socket, address, port, packet)
              state
          end

        {:noreply, state, {:continue, :recv}}

      {:error, reason} ->
        {:stop, reason}
    end
  end
end
