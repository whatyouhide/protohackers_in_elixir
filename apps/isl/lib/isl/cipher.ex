defmodule ISL.Cipher do
  @type spec() :: [
          :reversebits
          | {:xor, byte()}
          | :xorpos
          | {:add, byte()}
          | {:sub, byte()}
          | :addpos
          | :subpos
        ]

  import Bitwise
  import Kernel, except: [apply: 3]

  require Integer

  @doc """
  Parses a cipher spec as per the problem description.

  ## Examples

      iex> ISL.Cipher.parse_spec(<<0x00>>)
      {:ok, [], ""}

      iex> ISL.Cipher.parse_spec(<<0x01, 0x00>>)
      {:ok, [:reversebits], ""}

      iex> ISL.Cipher.parse_spec(<<0x02, 0x01, 0x01, 0x00>>)
      {:ok, [{:xor, 1}, :reversebits], ""}

      iex> ISL.Cipher.parse_spec(<<0x05, 0x05, 0x00>>)
      {:ok, [:addpos, :addpos], ""}

      iex> ISL.Cipher.parse_spec(<<0x03, 0x04, 0xbb, 0x00>>)
      {:ok, [:xorpos, {:add, 0xbb}], ""}

  Specs with unknown bytes, no bytes, or not ending with `0x00` are errors:

      iex> ISL.Cipher.parse_spec(<<>>)
      :error
      iex> ISL.Cipher.parse_spec(<<0x01>>)
      :error
      iex> ISL.Cipher.parse_spec(<<0x10>>)
      :error

  """
  @spec parse_spec(binary()) :: {:ok, spec(), binary()} | :error
  def parse_spec(spec) when is_binary(spec) do
    parse_spec(spec, _acc = [])
  end

  defp parse_spec(<<0x00, rest::binary>>, acc), do: {:ok, Enum.reverse(acc), rest}
  defp parse_spec(<<0x01, rest::binary>>, acc), do: parse_spec(rest, [:reversebits | acc])
  defp parse_spec(<<0x02, n, rest::binary>>, acc), do: parse_spec(rest, [{:xor, n} | acc])
  defp parse_spec(<<0x03, rest::binary>>, acc), do: parse_spec(rest, [:xorpos | acc])
  defp parse_spec(<<0x04, n, rest::binary>>, acc), do: parse_spec(rest, [{:add, n} | acc])
  defp parse_spec(<<0x05, rest::binary>>, acc), do: parse_spec(rest, [:addpos | acc])
  defp parse_spec(_other, _acc), do: :error

  @doc """

  ## Examples

      iex> spec = [{:xor, 0x67}, {:xor, 0xb5}, {:xor, 0xaf}, {:xor, 0xff}, {:xor, 0x82}]
      iex> ISL.Cipher.no_op?(spec)
      true

      iex> spec = [{:add, 20}, {:add, 236}, {:xor, 0}, {:add, 59}, {:add, 74}, {:add, 123}, :reversebits, :reversebits, {:xor, 0}]
      iex> ISL.Cipher.no_op?(spec)
      true

      iex> spec = [{:xor, 49}, {:xor, 216}, :xorpos, {:xor, 126}, {:xor, 191}, {:xor, 40}, :xorpos]
      iex> ISL.Cipher.no_op?(spec)
      true

      iex> spec = [{:xor, 168}, {:xor, 142}, :reversebits, {:xor, 255}, {:xor, 252}, {:xor, 103}, :reversebits]
      iex> ISL.Cipher.no_op?(spec)
      true

      iex> ISL.Cipher.no_op?([{:xor, 123}, :addpos, :reversebits])
      false

      iex> ISL.Cipher.no_op?([{:xor, 123}, :xorpos, :xorpos])
      false

      iex> ISL.Cipher.no_op?([:xorpos, :xorpos])
      true

      iex> {:ok, spec, ""} = ISL.Cipher.parse_spec(<<0x02, 0x01, 0x00>>)
      iex> ISL.Cipher.no_op?(spec)
      false

  """
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

  @doc """
  Applies a cipher spec to the given data.

  ## Examples

      iex> ISL.Cipher.apply("hello", [{:xor, 1}, :reversebits], 0)
      <<0x96, 0x26, 0xb6, 0xb6, 0x76>>

      iex> ISL.Cipher.apply("hello", [:addpos, :addpos], 0)
      <<0x68, 0x67, 0x70, 0x72, 0x77>>

      iex> ISL.Cipher.apply(<<0x00, 0x01, 0x02>>, [{:add, 3}], 0)
      <<0x03, 0x04, 0x05>>

      iex> ISL.Cipher.apply(<<0x00, 0x01, 0x02>>, [:xorpos], 2)
      <<0x02, 0x02, 0x06>>

  """
  @spec apply(binary(), spec(), non_neg_integer()) :: binary()
  def apply(data, spec, start_position)
      when is_binary(data) and is_list(spec) and is_integer(start_position) and
             start_position >= 0 do
    {encoded, _position} =
      for <<byte <- data>>, reduce: {<<>>, start_position} do
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
  defp apply_operation({:sub, n}, byte, _position), do: rem(byte - n, 256)
  defp apply_operation(:addpos, byte, position), do: rem(byte + position, 256)
  defp apply_operation(:subpos, byte, position), do: rem(byte - position, 256)

  @doc """
  Reverses the bits of the given byte.

  ## Examples

      iex> ISL.Cipher.reverse_bits(0b00000000)
      0b00000000

      iex> ISL.Cipher.reverse_bits(0b00000001)
      0b10000000

  """
  @spec reverse_bits(byte()) :: byte()
  def reverse_bits(byte) when is_integer(byte) and byte in 0..255 do
    <<b1::1, b2::1, b3::1, b4::1, b5::1, b6::1, b7::1, b8::1>> = <<byte>>
    <<reversed>> = <<b8::1, b7::1, b6::1, b5::1, b4::1, b3::1, b2::1, b1::1>>
    reversed
  end

  @doc """
  Semantically reverses a spec.

  ## Examples

      iex> ISL.Cipher.reverse_spec([:reversebits, :xorpos, :addpos, {:xor, 3}, {:add, 9}])
      [{:add, -9}, {:xor, 3}, :subpos, :xorpos, :reversebits]

  """
  @spec reverse_spec(spec()) :: spec()
  def reverse_spec(spec) when is_list(spec) do
    spec
    |> Enum.reverse()
    |> Enum.map(fn
      :addpos -> :subpos
      {:add, n} -> {:add, -n}
      other -> other
    end)
  end
end
