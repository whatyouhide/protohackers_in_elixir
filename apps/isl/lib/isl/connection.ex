defmodule ISL.Connection do
  use ThousandIsland.Handler

  alias ISL.Cipher

  require Logger

  defstruct [
    :cipher_spec,
    :reverse_cipher_spec,
    buffer: <<>>,
    client_position: 0,
    server_position: 0
  ]

  @impl true
  def handle_connection(_socket, _handler_opts = []) do
    {:continue, %__MODULE__{}}
  end

  @impl true
  def handle_data(data, socket, state) do
    Logger.debug("<-- #{inspect(data, base: :hex)}")

    case handle_new_data(state, socket, data) do
      {:ok, state} -> {:continue, state}
      :error -> {:close, state}
    end
  end

  ## Helpers

  # If we don't have a cipher spec, we try to parse one first.
  defp handle_new_data(%__MODULE__{cipher_spec: nil} = state, socket, data) do
    state = update_in(state.buffer, &(&1 <> data))

    case parse_cipher_spec(state) do
      {:ok, state, rest} -> handle_new_data(state, socket, rest)
      :error -> :error
    end
  end

  # If we have a cipher spec already, we can decode all incoming data and handle the decoded
  # data directly.
  defp handle_new_data(%__MODULE__{} = state, socket, data) do
    data = Cipher.apply(data, state.reverse_cipher_spec, state.client_position)
    Logger.debug("Handling decoded data at position #{state.client_position}: #{inspect(data)}")
    state = update_in(state.client_position, &(&1 + byte_size(data)))
    state = update_in(state.buffer, &(&1 <> data))
    handle_new_decoded_data(state, socket)
  end

  defp parse_cipher_spec(%__MODULE__{buffer: data, cipher_spec: nil} = state) do
    case Cipher.parse_spec(data) do
      {:ok, cipher_spec, rest} ->
        if Cipher.no_op?(cipher_spec) do
          Logger.error("No-op cipher spec")
          :error
        else
          Logger.debug("Parsed cipher: #{inspect(cipher_spec)}")
          state = put_in(state.cipher_spec, cipher_spec)
          state = put_in(state.reverse_cipher_spec, Cipher.reverse_spec(cipher_spec))
          state = put_in(state.buffer, <<>>)
          {:ok, state, rest}
        end

      :error ->
        :error
    end
  end

  defp handle_new_decoded_data(%__MODULE__{} = state, socket) do
    case String.split(state.buffer, "\n", parts: 2) do
      [line, rest] ->
        state = put_in(state.buffer, rest)
        state = handle_line(state, socket, line)
        handle_new_decoded_data(state, socket)

      [_buffer] ->
        {:ok, state}
    end
  end

  defp handle_line(%__MODULE__{} = state, socket, line) do
    encoded =
      line
      |> String.split(",")
      |> Enum.max_by(fn toy_spec ->
        case Integer.parse(toy_spec) do
          {quantity, "x " <> _toy} -> quantity
          :error -> raise "invalid packet"
        end
      end)
      |> Kernel.<>("\n")
      |> Cipher.apply(state.cipher_spec, state.server_position)

    ThousandIsland.Socket.send(socket, encoded)
    update_in(state.server_position, &(&1 + byte_size(encoded)))
  end
end
