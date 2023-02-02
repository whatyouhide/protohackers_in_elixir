defmodule LineReversal.Acceptor do
  use Task, restart: :transient

  alias LineReversal.{LRCP, Connection}

  require Logger

  @spec start_link(keyword()) :: {:ok, pid()}
  def start_link(options) when is_list(options) do
    ip = Keyword.fetch!(options, :ip)
    port = Keyword.fetch!(options, :port)
    Task.start_link(__MODULE__, :__accept__, [ip, port])
  end

  ## Private

  def __accept__(ip, port) when is_tuple(ip) and is_integer(port) do
    case LRCP.listen(ip, port) do
      {:ok, listen_socket} ->
        Logger.info("Listening for LRCP connections on port #{port}")
        loop(listen_socket)

      {:error, reason} ->
        raise "failed to start LRCP listen socket on port #{port}: #{inspect(reason)}"
    end
  end

  defp loop(listen_socket) do
    case LRCP.accept(listen_socket) do
      {:ok, socket} ->
        {:ok, handler} = Connection.start_link(socket)
        :ok = LRCP.controlling_process(socket, handler)
        loop(listen_socket)

      {:error, reason} ->
        raise "failed to accept LRCP connection: #{inspect(reason)}"
    end
  end
end
