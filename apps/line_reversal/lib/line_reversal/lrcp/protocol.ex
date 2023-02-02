defmodule LineReversal.LRCP.Protocol do
  @type session_id() :: integer()

  @type packet() ::
          {:connect, session_id()}
          | {:close, session_id()}
          | {:data, session_id(), integer(), binary()}
          | {:ack, session_id(), integer()}

  @max_int 2_147_483_648

  @spec session_id(packet()) :: session_id()
  def session_id({:connect, session_id}), do: session_id
  def session_id({:close, session_id}), do: session_id
  def session_id({:data, session_id, _position, _data}), do: session_id
  def session_id({:ack, session_id, _position}), do: session_id

  @spec parse_packet(binary()) :: {:ok, packet()} | :error
  def parse_packet(binary) do
    with <<?/, rest::binary>> <- binary,
         {:ok, parts} <- split(rest, _acc = [], _part = <<>>) do
      parse_packet_fields(parts)
    else
      _other -> :error
    end
  end

  defp split(<<>>, _acc, _part), do: :error
  defp split(<<?/>> = _end, acc, part), do: {:ok, Enum.reverse([part | acc])}
  defp split(<<"\\/", rest::binary>>, acc, part), do: split(rest, acc, <<part::binary, "\\/">>)
  defp split(<<?/, rest::binary>>, acc, part), do: split(rest, [part | acc], <<>>)
  defp split(<<char, rest::binary>>, acc, part), do: split(rest, acc, <<part::binary, char>>)

  defp parse_packet_fields([type, session_id]) when type in ["connect", "close"] do
    with {:ok, session_id} <- parse_int(session_id) do
      {:ok, {String.to_existing_atom(type), session_id}}
    end
  end

  defp parse_packet_fields(["data", session_id, position, data]) do
    with {:ok, session_id} <- parse_int(session_id),
         {:ok, position} <- parse_int(position) do
      {:ok, {:data, session_id, position, data}}
    end
  end

  defp parse_packet_fields(["ack", session_id, position]) do
    with {:ok, session_id} <- parse_int(session_id),
         {:ok, position} <- parse_int(position) do
      {:ok, {:ack, session_id, position}}
    end
  end

  defp parse_packet_fields(_other) do
    :error
  end

  defp parse_int(bin) do
    case Integer.parse(bin) do
      {int, ""} when int < @max_int -> {:ok, int}
      _ -> :error
    end
  end
end
