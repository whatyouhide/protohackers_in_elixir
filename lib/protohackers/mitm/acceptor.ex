defmodule Protohackers.MITM.Acceptor do
  use Task, restart: :transient

  require Logger

  def start_link([] = _opts) do
    Task.start_link(__MODULE__, :run, [])
  end

  def run do
    case :gen_tcp.listen(5006, [
           :binary,
           ifaddr: {0, 0, 0, 0},
           active: :once,
           packet: :line,
           reuseaddr: true
         ]) do
      {:ok, listen_socket} ->
        Logger.info("MITM server listening on port 5006")
        accept_loop(listen_socket)

      {:error, reason} ->
        raise "failed to listen on port 5006: #{inspect(reason)}"
    end
  end

  defp accept_loop(listen_socket) do
    case :gen_tcp.accept(listen_socket) do
      {:ok, socket} ->
        {:ok, _} = Protohackers.MITM.ConnectionSupervisor.start_child(socket)
        accept_loop(listen_socket)

      {:error, reason} ->
        raise "failed to accept connection: #{inspect(reason)}"
    end
  end
end
