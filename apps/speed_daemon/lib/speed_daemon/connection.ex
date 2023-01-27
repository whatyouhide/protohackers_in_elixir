defmodule SpeedDaemon.Connection do
  use GenServer, restart: :temporary

  alias SpeedDaemon.{CentralTicketDispatcher, DispatchersRegistry, Message}

  require Logger

  def start_link(socket) do
    GenServer.start_link(__MODULE__, socket)
  end

  defstruct [:socket, :type, :heartbeat_ref, buffer: <<>>]

  @impl true
  def init(socket) do
    Logger.debug("Client connected")
    {:ok, %__MODULE__{socket: socket}}
  end

  @impl true
  def handle_info(message, state)

  def handle_info({:tcp, socket, data}, %__MODULE__{socket: socket} = state) do
    state = update_in(state.buffer, &(&1 <> data))
    :ok = :inet.setopts(socket, active: :once)
    parse_all_data(state)
  end

  def handle_info({:tcp_error, socket, reason}, %__MODULE__{socket: socket} = state) do
    Logger.error("Connection closed because of error: #{inspect(reason)}")
    {:stop, :normal, state}
  end

  def handle_info({:tcp_closed, socket}, %__MODULE__{socket: socket} = state) do
    Logger.debug("Connection closed by client")
    {:stop, :normal, state}
  end

  def handle_info(:send_heartbeat, %__MODULE__{} = state) do
    send_message(state, %Message.Heartbeat{})
    {:noreply, state}
  end

  @impl true
  def handle_cast({:dispatch_ticket, ticket}, %__MODULE__{type: %Message.IAmDispatcher{}} = state) do
    send_message(state, ticket)
    {:noreply, state}
  end

  ## Helpers

  defp send_message(%__MODULE__{socket: socket}, message) do
    Logger.debug("Sending message: #{inspect(message)}")
    :gen_tcp.send(socket, Message.encode(message))
  end

  defp parse_all_data(%__MODULE__{} = state) do
    case Message.decode(state.buffer) do
      {:ok, message, rest} ->
        Logger.debug("Received message: #{inspect(message)}")
        state = put_in(state.buffer, rest)

        case handle_message(state, message) do
          {:ok, state} ->
            parse_all_data(state)

          {:error, message} ->
            send_message(state, %Message.Error{message: message})
            {:stop, :normal, state}
        end

      :incomplete ->
        {:noreply, state}

      :error ->
        send_message(state, %Message.Error{message: "Invalid protocol message"})
        {:stop, :normal, state}
    end
  end

  defp handle_message(
         %__MODULE__{type: %Message.IAmCamera{} = camera} = state,
         %Message.Plate{} = message
       ) do
    CentralTicketDispatcher.register_observation(
      camera.road,
      camera.mile,
      message.plate,
      message.timestamp
    )

    {:ok, state}
  end

  defp handle_message(%__MODULE__{type: _other_type}, %Message.Plate{}) do
    {:error, "Plate messages are only accepted from cameras"}
  end

  defp handle_message(state, %Message.WantHeartbeat{interval: interval}) do
    interval_in_ms = interval * 100

    if state.heartbeat_ref do
      :timer.cancel(state.heartbeat_ref)
    end

    if interval > 0 do
      {:ok, heartbeat_ref} = :timer.send_interval(interval_in_ms, :send_heartbeat)
      {:ok, %__MODULE__{state | heartbeat_ref: heartbeat_ref}}
    else
      {:ok, %__MODULE__{state | heartbeat_ref: nil}}
    end
  end

  defp handle_message(%__MODULE__{type: nil} = state, %Message.IAmCamera{} = message) do
    CentralTicketDispatcher.add_road(message.road, message.limit)
    Logger.metadata(type: :camera, road: message.road, mile: message.mile)

    {:ok, %__MODULE__{state | type: message}}
  end

  defp handle_message(%__MODULE__{type: _other}, %Message.IAmCamera{}) do
    {:error, "Already registered as a dispatcher or a camera"}
  end

  defp handle_message(%__MODULE__{type: nil} = state, %Message.IAmDispatcher{} = message) do
    Enum.each(message.roads, fn road ->
      {:ok, _} = Registry.register(DispatchersRegistry, road, :unused_value)
    end)

    Logger.metadata(type: :dispatcher)
    {:ok, %__MODULE__{state | type: message}}
  end

  defp handle_message(%__MODULE__{type: _other}, %Message.IAmDispatcher{}) do
    {:error, "Already registered as a dispatcher or a camera"}
  end

  defp handle_message(%__MODULE__{}, _message) do
    {:error, "Invalid message"}
  end
end
