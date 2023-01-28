defmodule LineReversal.Connection do
  use GenServer, restart: :temporary

  alias LineReversal.LRCP

  require Logger

  @spec start_link(LRCP.socket()) :: GenServer.on_start()
  def start_link(lrcp_socket) do
    GenServer.start_link(__MODULE__, lrcp_socket)
  end

  ## Callbacks

  defstruct [:socket, buffer: <<>>]

  @impl true
  def init(socket) do
    Logger.debug("Connection started: #{inspect(socket)}")
    {:ok, %__MODULE__{socket: socket}}
  end

  @impl true
  def handle_info(message, state)

  def handle_info({:lrcp, socket, data}, %__MODULE__{socket: socket} = state) do
    Logger.debug("Received LRCP data: #{inspect(data)}")
    state = update_in(state.buffer, &(&1 <> data))
    state = handle_new_data(state)
    {:noreply, state}
  end

  def handle_info({:lrcp_error, socket, reason}, %__MODULE__{socket: socket} = state) do
    Logger.error("Closing connection due to error: #{inspect(reason)}")
    {:stop, :normal, state}
  end

  def handle_info({:lrcp_closed, socket}, %__MODULE__{socket: socket} = state) do
    Logger.debug("Connection closed")
    {:stop, :normal, state}
  end

  ## Helpers

  defp handle_new_data(%__MODULE__{} = state) do
    case String.split(state.buffer, "\n", parts: 2) do
      [line, rest] ->
        LRCP.send(state.socket, String.reverse(line) <> "\n")
        handle_new_data(put_in(state.buffer, rest))

      [_no_line_yet] ->
        state
    end
  end
end
