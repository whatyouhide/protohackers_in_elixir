defmodule LineReversal.LRCP.Protocol do
  @type session_id() :: integer()

  @type packet() ::
          {:connect, session_id()}
          | {:close, session_id()}
          | {:data, session_id(), integer(), binary()}
          | {:ack, session_id(), integer()}

  @spec session_id(packet()) :: session_id()
  def session_id({:connect, session_id}), do: session_id
  def session_id({:close, session_id}), do: session_id
  def session_id({:data, session_id, _position, _data}), do: session_id
  def session_id({:ack, session_id, _position}), do: session_id

  @spec parse_packet(binary()) :: {:ok, packet()} | :error
  def parse_packet(packet) when is_binary(packet) do
    case packet |> String.split(~r{([^\\]|^)\K/}) |> Enum.split(-1) do
      {["" | fields], [""]} -> parse_packet_fields(fields)
      _other -> :error
    end
  end

  defp parse_packet_fields([type, session_id]) when type in ["connect", "close"] do
    case Integer.parse(session_id) do
      {session_id, ""} -> {:ok, {String.to_existing_atom(type), session_id}}
      :error -> :error
    end
  end

  defp parse_packet_fields(["data", session_id, position, data]) do
    with {session_id, ""} <- Integer.parse(session_id),
         {position, ""} <- Integer.parse(position) do
      {:ok, {:data, session_id, position, data}}
    else
      _ -> :error
    end
  end

  defp parse_packet_fields(["ack", session_id, position]) do
    with {session_id, ""} <- Integer.parse(session_id),
         {position, ""} <- Integer.parse(position) do
      {:ok, {:ack, session_id, position}}
    else
      _ -> :error
    end
  end

  defp parse_packet_fields(_other) do
    :error
  end
end
