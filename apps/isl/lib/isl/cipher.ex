defmodule ISL.Cipher do
  @type spec() :: [
          :reversebits
          | {:xor, byte()}
          | :xorpos
          | {:add, byte()}
          | :addpos
          | {:sub, byte()}
          | :subpos
        ]

  import Bitwise

  require Integer

  @doc """
  ## Examples

      iex> ISL.Cipher.parse_spec(<<0x00>>)
      {:ok, [], <<>>}

      iex> ISL.Cipher.parse_spec(<<0x00, "hello">>)
      {:ok, [], "hello"}

      iex> ISL.Cipher.parse_spec(<<0x02, 0xaa, 0x01, 0x00, "hello">>)
      {:ok, [{:xor, 0xaa}, :reversebits], "hello"}

      iex> ISL.Cipher.parse_spec(<<0xff>>)
      :error

      iex> ISL.Cipher.parse_spec(<<0x01>>)
      :error

  """
  @spec parse_spec(binary()) :: {:ok, spec(), binary()} | :error
  def parse_spec(binary) when is_binary(binary) do
    parse_spec(binary, _acc = [])
  end

  defp parse_spec(<<0x00, rest::binary>>, acc), do: {:ok, Enum.reverse(acc), rest}
  defp parse_spec(<<0x01, rest::binary>>, acc), do: parse_spec(rest, [:reversebits | acc])
  defp parse_spec(<<0x02, n, rest::binary>>, acc), do: parse_spec(rest, [{:xor, n} | acc])
  defp parse_spec(<<0x03, rest::binary>>, acc), do: parse_spec(rest, [:xorpos | acc])
  defp parse_spec(<<0x04, n, rest::binary>>, acc), do: parse_spec(rest, [{:add, n} | acc])
  defp parse_spec(<<0x05, rest::binary>>, acc), do: parse_spec(rest, [:addpos | acc])
  defp parse_spec(_other, _acc), do: :error

  @doc """

      iex> ISL.Cipher.apply("hello", [{:xor, 1}, :reversebits], 0)
      <<0x96, 0x26, 0xb6, 0xb6, 0x76>>

  """
  @spec apply(binary(), spec(), non_neg_integer()) :: binary()
  def apply(data, spec, start_position) do
    {encoded, _position} =
      for <<byte <- data>>, reduce: {_acc = <<>>, start_position} do
        {acc, position} ->
          encoded = Enum.reduce(spec, byte, &apply_operation(&1, &2, position))
          {<<acc::binary, encoded>>, position + 1}
      end

    encoded
  end

  defp apply_operation(:reversebits, byte, _position), do: reverse_bits(byte)
  defp apply_operation({:xor, n}, byte, _position), do: bxor(n, byte)
  defp apply_operation(:xorpos, byte, position), do: bxor(byte, position)
  defp apply_operation({:add, n}, byte, _position), do: rem(byte + n, 256)
  defp apply_operation(:addpos, byte, position), do: rem(byte + position, 256)
  defp apply_operation({:sub, n}, byte, _position), do: rem(byte - n, 256)
  defp apply_operation(:subpos, byte, position), do: rem(byte - position, 256)

  @doc """

      iex> ISL.Cipher.reverse_bits(0b00000001)
      0b10000000

  """
  @spec reverse_bits(byte()) :: byte()
  def reverse_bits(byte) do
    <<b1::1, b2::1, b3::1, b4::1, b5::1, b6::1, b7::1, b8::1>> = <<byte>>
    <<reversed>> = <<b8::1, b7::1, b6::1, b5::1, b4::1, b3::1, b2::1, b1::1>>
    reversed
  end

  @doc """
      iex> ISL.Cipher.reverse_spec([:reversebits, :xorpos, :addpos, {:xor, 3}, {:add, 9}])
      [{:sub, 9}, {:xor, 3}, :subpos, :xorpos, :reversebits]
  """
  @spec reverse_spec(spec()) :: spec()
  def reverse_spec(spec) do
    spec
    |> Enum.reverse()
    |> Enum.map(fn
      :addpos -> :subpos
      {:add, n} -> {:sub, n}
      other -> other
    end)
  end

  @spec no_op?(spec()) :: boolean()
  def no_op?(ops) do
    {xorpos_ops, ops} = Enum.split_with(ops, &(&1 == :xorpos))

    {adds, ops} = Enum.split_with(ops, &match?({:add, _}, &1))
    total_add = Enum.reduce(adds, 0, fn {:add, n}, acc -> rem(n + acc, 256) end)
    {addpos_ops, ops} = Enum.split_with(ops, &(&1 == :addpos))

    cond do
      Integer.is_odd(length(xorpos_ops)) -> false
      addpos_ops != [] -> false
      total_add != 0 -> false
      true -> no_op_rest?(ops, _xor_acc = 0, _reversed? = false)
    end
  end

  defp no_op_rest?([], _xor_acc = 0, _reversed? = false), do: true
  defp no_op_rest?([], _xor_acc, _reversed?), do: false

  defp no_op_rest?([:reversebits, :reversebits | rest], xor_acc, reversed?) do
    no_op_rest?(rest, xor_acc, reversed?)
  end

  defp no_op_rest?([:reversebits | [{:xor, _} | _] = rest], xor_acc, reversed?) do
    rest
    |> Enum.map(fn
      {:xor, n} -> {:xor, reverse_bits(n)}
      other -> other
    end)
    |> no_op_rest?(xor_acc, not reversed?)
  end

  defp no_op_rest?([{:xor, _} | _] = spec, xor_acc, reversed?) do
    {xors, rest} = Enum.split_while(spec, &match?({:xor, _}, &1))
    xor_acc = Enum.reduce(xors, xor_acc, fn {:xor, n}, acc -> bxor(n, acc) end)
    no_op_rest?(rest, xor_acc, reversed?)
  end

  defp no_op_rest?([:reversebits | rest], xor_acc, reversed?) do
    no_op_rest?(rest, xor_acc, not reversed?)
  end
end
