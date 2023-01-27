defmodule Protohackers.PricesServer.DB do
  @type timestamp() :: integer()
  @type price() :: integer()
  @type t() :: [{timestamp(), price()}]

  @spec new() :: t()
  def new do
    []
  end

  @spec add(t(), timestamp(), price()) :: t()
  def add(db, timestamp, price)
      when is_list(db) and is_integer(timestamp) and is_integer(price) do
    [{timestamp, price} | db]
  end

  @spec query(t(), timestamp(), timestamp()) :: price()
  def query(db, from, to) when is_list(db) and is_integer(from) and is_integer(to) do
    db
    |> Stream.filter(fn {timestamp, _price} -> timestamp >= from and timestamp <= to end)
    |> Stream.map(fn {_timestamp, price} -> price end)
    |> Enum.reduce({0, 0}, fn price, {sum, count} -> {sum + price, count + 1} end)
    |> then(fn
      {_sum, 0} -> 0
      {sum, count} -> div(sum, count)
    end)
  end
end
