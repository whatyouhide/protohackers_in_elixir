defmodule LineReversal.LRCP do
  alias LineReversal.LRCP.{ListenSocket, Socket}

  @type listen_socket() :: ListenSocket.t()
  @type socket() :: Socket.t()

  @spec listen(:inet.ip_address(), :inet.port_number()) ::
          {:ok, listen_socket()} | {:error, term()}
  def listen(ip, port) when is_tuple(ip) and is_integer(port) do
    ListenSocket.start_link(ip: ip, port: port)
  end

  @spec accept(listen_socket()) :: {:ok, socket()} | {:error, term()}
  def accept(%ListenSocket{} = listen_socket) do
    ListenSocket.accept(listen_socket)
  end

  @spec controlling_process(socket(), pid()) :: :ok | {:error, term()}
  def controlling_process(%Socket{} = socket, pid) when is_pid(pid) do
    Socket.controlling_process(socket, pid)
  end

  @spec send(socket(), binary()) :: :ok | {:error, term()}
  def send(%Socket{} = socket, data) when is_binary(data) do
    Socket.send(socket, data)
  end
end
