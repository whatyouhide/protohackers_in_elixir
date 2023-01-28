defmodule LineReversal.LRCP.ListenSocket do
  use GenServer

  alias LineReversal.LRCP

  require Logger

  @type t() :: %__MODULE__{pid: pid()}

  defstruct [:pid]

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(options) when is_list(options) do
    with {:ok, pid} <- GenServer.start_link(__MODULE__, options) do
      {:ok, %__MODULE__{pid: pid}}
    end
  end

  @spec accept(t()) :: {:ok, LRCP.socket()} | {:error, term()}
  def accept(%__MODULE__{pid: pid} = _listen_socket) do
    GenServer.call(pid, :accept, _timeout = :infinity)
  end

  ## Callbacks

  defmodule State do
    defstruct [
      :udp_socket,
      :supervisor,
      accept_queue: :queue.new(),
      ready_sockets: :queue.new()
    ]
  end

  @impl true
  def init(options) do
    ip = Keyword.fetch!(options, :ip)
    port = Keyword.fetch!(options, :port)

    udp_options = [
      :binary,
      active: :once,
      recbuf: 10_000,
      ip: ip
    ]

    Logger.metadata(address: "#{:inet.ntoa(ip)}:#{port}")

    with {:ok, udp_socket} <- :gen_udp.open(port, udp_options),
         {:ok, supervisor} <- DynamicSupervisor.start_link(max_children: 200) do
      Logger.debug("Listening for UDP connections")
      {:ok, %State{udp_socket: udp_socket, supervisor: supervisor}}
    else
      {:error, reason} -> {:stop, reason}
    end
  end

  @impl true
  def handle_call(:accept, from, state) do
    case get_and_update_in(state.ready_sockets, &:queue.out/1) do
      # There is a socket ready to be handled.
      {{:value, %LRCP.Socket{} = socket}, state} ->
        Logger.debug("Accepted connection #{inspect(socket)} from the queue")
        {:reply, {:ok, socket}, state}

      # No sockets are ready, so we queue this client for when a socket is ready.
      {:empty, state} ->
        state = update_in(state.accept_queue, &:queue.in(from, &1))
        Logger.debug("Queued accept call")
        {:noreply, state}
    end
  end

  @impl true
  def handle_info({:udp, udp_socket, ip, port, packet}, %State{udp_socket: udp_socket} = state) do
    :ok = :inet.setopts(udp_socket, active: :once)
    Logger.debug("<-- #{inspect(packet)}")

    case LRCP.Protocol.parse_packet(packet) do
      {:ok, packet} ->
        handle_packet(state, ip, port, packet)

      :error ->
        Logger.debug("Invalid packet, ignoring it: #{inspect(packet)}")
        {:noreply, state}
    end
  end

  ## Helpers

  defp handle_packet(state, ip, port, {:connect, session_id}) do
    spec = {LRCP.Socket, [%__MODULE__{pid: self()}, state.udp_socket, ip, port, session_id]}

    case DynamicSupervisor.start_child(state.supervisor, spec) do
      # We started a new child.
      {:ok, socket_pid} ->
        socket = %LRCP.Socket{pid: socket_pid}

        case get_and_update_in(state.accept_queue, &:queue.out/1) do
          # If there is a pending accept, we can reply to it.
          {{:value, from}, state} ->
            Logger.debug("Handing over socket #{inspect(socket)} to queued client")
            GenServer.reply(from, {:ok, socket})
            {:noreply, state}

          # If there is nothing blocked on accepting, we queue this socket.
          {:empty, state} ->
            state = update_in(state.ready_sockets, &:queue.in(socket, &1))
            {:noreply, state}
        end

      # The connection for this session ID is already running, so we just resend the ack.
      {:error, {:already_started, _pid}} ->
        :ok = LRCP.Socket.resend_connect_ack(%__MODULE__{pid: self()}, session_id)
        {:noreply, state}

      {:error, reason} ->
        Logger.error("Failed to start connection: #{inspect(reason)}")
        {:noreply, state}
    end
  end

  defp handle_packet(state, ip, port, {:close, session_id}) do
    _ = LRCP.Socket.close(%__MODULE__{pid: self()}, session_id)
    send_close(state, ip, port, session_id)
    {:noreply, state}
  end

  defp handle_packet(state, ip, port, packet) do
    case LRCP.Socket.handle_packet(%__MODULE__{pid: self()}, packet) do
      :ok -> :ok
      :not_found -> send_close(state, ip, port, LRCP.Protocol.session_id(packet))
    end

    {:noreply, state}
  end

  defp send_close(state, ip, port, session_id) do
    Logger.debug("--> \"/close/#{session_id}/\"")
    :ok = :gen_udp.send(state.udp_socket, ip, port, "/close/#{session_id}/")
  end
end
