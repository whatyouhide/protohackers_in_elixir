defmodule SpeedDaemon.Acceptor do
  use Task, restart: :transient

  require Logger

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts) do
    Task.start_link(__MODULE__, :run, [Keyword.fetch!(opts, :port)])
  end

  @spec run(:inet.port_number()) :: no_return()
  def run(port) do
    case :gen_tcp.listen(port, [
           :binary,
           ifaddr: {0, 0, 0, 0},
           active: :once,
           reuseaddr: true
         ]) do
      {:ok, listen_socket} ->
        Logger.info("Listening on port #{port}")
        accept_loop(listen_socket)

      {:error, reason} ->
        raise "failed to listen on port #{port}: #{inspect(reason)}"
    end
  end

  defp accept_loop(listen_socket) do
    case :gen_tcp.accept(listen_socket) do
      {:ok, socket} ->
        {:ok, _} = SpeedDaemon.ConnectionSupervisor.start_child(socket)
        accept_loop(listen_socket)

      {:error, reason} ->
        raise "failed to accept connection: #{inspect(reason)}"
    end
  end
end
