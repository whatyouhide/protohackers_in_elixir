defmodule LineReversal.LRCP.Socket do
  use GenServer, restart: :temporary

  import Kernel, except: [send: 2]

  alias LineReversal.LRCP

  require Logger

  @type t() :: %__MODULE__{pid: pid()}

  @max_data_length 1_000 - String.length("/data/2147483648/2147483648//")
  @idle_timeout 60_000

  if Mix.env() == :test do
    @retransmit_interval 100
  else
    @retransmit_interval 3_000
  end

  defstruct [:pid]

  @spec start_link(list()) :: GenServer.on_start()
  def start_link([
        %LRCP.ListenSocket{} = listen_socket,
        udp_socket,
        peer_ip,
        peer_port,
        session_id
      ]) do
    name = name(listen_socket, session_id)
    GenServer.start_link(__MODULE__, {udp_socket, peer_ip, peer_port, session_id}, name: name)
  end

  @spec send(t(), binary()) :: :ok | {:error, term()}
  def send(%__MODULE__{} = socket, data) when is_binary(data) do
    GenServer.call(socket.pid, {:send, data})
  end

  @spec controlling_process(t(), pid()) :: :ok
  def controlling_process(%__MODULE__{} = socket, pid) when is_pid(pid) do
    GenServer.call(socket.pid, {:controlling_process, pid})
  catch
    :exit, {:noproc, _} ->
      Kernel.send(pid, {:lrcp_closed, socket})
      :ok
  end

  @spec resend_connect_ack(LRCP.listen_socket(), integer()) :: :ok
  def resend_connect_ack(%LRCP.ListenSocket{} = listen_socket, session_id) do
    GenServer.cast(name(listen_socket, session_id), :resend_connect_ack)
  end

  @spec handle_packet(LRCP.listen_socket(), packet) :: :ok | :not_found
        when packet:
               {:data, LRCP.Protocol.session_id(), integer(), binary()}
               | {:ack, LRCP.Protocol.session_id(), integer()}
  def handle_packet(%LRCP.ListenSocket{} = listen_socket, packet) when is_tuple(packet) do
    session_id = LRCP.Protocol.session_id(packet)

    if pid = GenServer.whereis(name(listen_socket, session_id)) do
      GenServer.cast(pid, {:handle_packet, packet})
    else
      :not_found
    end
  end

  @spec close(LRCP.listen_socket(), integer()) :: :ok
  def close(%LRCP.ListenSocket{} = listen_socket, session_id) do
    GenServer.cast(name(listen_socket, session_id), :close)
  end

  defp name(%LRCP.ListenSocket{} = listen_socket, session_id) when is_integer(session_id) do
    {:via, Registry, {LineReversal.Registry, {listen_socket, session_id}}}
  end

  ## Callbacks

  defmodule State do
    defstruct [
      :udp_socket,
      :peer_ip,
      :peer_port,
      :session_id,
      :client,
      :idle_timer_ref,
      in_position: 0,
      out_position: 0,
      acked_out_position: 0,
      pending_out_payload: <<>>,
      out_message_queue: :queue.new()
    ]
  end

  @impl true
  def init({udp_socket, peer_ip, peer_port, session_id}) do
    Logger.metadata(session: session_id)

    idle_timer_ref = Process.send_after(self(), :idle_timeout, @idle_timeout)

    state = %State{
      udp_socket: udp_socket,
      peer_ip: peer_ip,
      peer_port: peer_port,
      session_id: session_id,
      idle_timer_ref: idle_timer_ref
    }

    udp_send(state, "/ack/#{state.session_id}/0/")

    {:ok, state}
  end

  @impl true
  def handle_info(message, state)

  def handle_info(:idle_timeout, %State{} = state) do
    Logger.info("Closing connection due to inactivity")
    {:stop, :normal, state}
  end

  def handle_info(:retransmit_pending_data, %State{} = state) do
    state = update_in(state.out_position, &(&1 - byte_size(state.pending_out_payload)))
    {:noreply, send_data(state, state.pending_out_payload)}
  end

  @impl true
  def handle_call({:send, data}, _from, %State{} = state) do
    state = update_in(state.pending_out_payload, &(&1 <> data))
    state = send_data(state, data)
    {:reply, :ok, state}
  end

  def handle_call({:controlling_process, pid}, _from, %State{} = state) do
    Logger.debug("Controlling process set to #{inspect(pid)}")
    state = put_in(state.client, pid)

    {messages, state} =
      get_and_update_in(state.out_message_queue, fn queue ->
        {:queue.to_list(queue), :queue.new()}
      end)

    Enum.each(messages, &Kernel.send(pid, &1))

    {:reply, :ok, state}
  end

  @impl true
  def handle_cast(cast, state)

  def handle_cast(:close, %State{} = state) do
    {:stop, :normal, state}
  end

  def handle_cast(:resend_connect_ack, %State{} = state) do
    udp_send(state, "/ack/#{state.session_id}/#{state.in_position}/")
    {:noreply, state}
  end

  def handle_cast({:handle_packet, {:data, _session_id, position, data}}, %State{} = state) do
    state = reset_idle_timer(state)

    if position == state.in_position do
      unescaped_data = unescape_data(data)
      state = update_in(state.in_position, &(&1 + byte_size(unescaped_data)))
      udp_send(state, "/ack/#{state.session_id}/#{state.in_position}/")
      state = send_or_queue_message(state, {:lrcp, %__MODULE__{pid: self()}, unescaped_data})
      {:noreply, state}
    else
      # If we're not caught up, we resend the ack with the position of where
      # we're caught up and keep going.
      udp_send(state, "/ack/#{state.session_id}/#{state.in_position}/")
      {:noreply, state}
    end
  end

  def handle_cast({:handle_packet, {:ack, _session_id, length}}, %State{} = state) do
    cond do
      length <= state.acked_out_position ->
        # Do nothing and stop, it's probably a duplicate ack.
        Logger.debug("Ignoring ack for #{length} bytes, we've already acked that")
        {:noreply, state}

      length > state.out_position ->
        # Client is misbehaving, close the session.
        Logger.debug(
          "Client is misbehaving, closing session (sent ack for position #{length} " <>
            "but we've only sent #{state.out_position} bytes)"
        )

        udp_send(state, "/close/#{state.session_id}/")

        state =
          send_or_queue_message(
            state,
            {:lrcp_error, %__MODULE__{pid: self()}, :client_misbehaving}
          )

        {:stop, :normal, state}

      length < state.acked_out_position + byte_size(state.pending_out_payload) ->
        transmitted_bytes = length - state.acked_out_position
        Logger.debug("Partial ack for #{transmitted_bytes} bytes")

        still_pending_payload =
          :binary.part(
            state.pending_out_payload,
            transmitted_bytes,
            byte_size(state.pending_out_payload) - transmitted_bytes
          )

        udp_send(
          state,
          "/data/#{state.session_id}/#{state.acked_out_position + transmitted_bytes}/" <>
            escape_data(still_pending_payload) <> "/"
        )

        state = put_in(state.acked_out_position, length)
        state = put_in(state.pending_out_payload, still_pending_payload)
        {:noreply, state}

      length == state.out_position ->
        Logger.debug("Everything we've sent has been acked")
        state = put_in(state.acked_out_position, length)
        state = put_in(state.pending_out_payload, <<>>)
        {:noreply, state}

      true ->
        raise """
        Should never reach this.

        state: #{inspect(state)}
        length: #{length}
        """
    end
  end

  ## Helpers

  defp send_data(%State{} = state, <<>>) do
    Process.send_after(self(), :retransmit_pending_data, @retransmit_interval)
    state
  end

  defp send_data(%State{} = state, data) do
    {chunk, rest} =
      case data do
        <<chunk::binary-size(@max_data_length), rest::binary>> -> {chunk, rest}
        chunk -> {chunk, ""}
      end

    udp_send(state, "/data/#{state.session_id}/#{state.out_position}/#{escape_data(chunk)}/")
    state = update_in(state.out_position, &(&1 + byte_size(chunk)))

    send_data(state, rest)
  end

  defp send_or_queue_message(%State{} = state, message) do
    if state.client do
      Logger.debug("Sending message to client: #{inspect(message)}")
      Kernel.send(state.client, message)
      state
    else
      Logger.debug("Queueing message: #{inspect(message)}")
      update_in(state.out_message_queue, &:queue.in(message, &1))
    end
  end

  defp escape_data(data) do
    data
    |> String.replace("\\", "\\\\")
    |> String.replace("/", "\\/")
  end

  defp unescape_data(data) do
    data
    |> String.replace("\\/", "/")
    |> String.replace("\\\\", "\\")
  end

  defp udp_send(%State{} = state, data) do
    Logger.debug("--> #{inspect(data)}")
    :ok = :gen_udp.send(state.udp_socket, state.peer_ip, state.peer_port, data)
  end

  defp reset_idle_timer(%State{} = state) do
    Process.cancel_timer(state.idle_timer_ref)
    idle_timer_ref = Process.send_after(self(), :idle_timeout, @idle_timeout)
    put_in(state.idle_timer_ref, idle_timer_ref)
  end
end
