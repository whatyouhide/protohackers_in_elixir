defmodule Protohackers.PricesServer.DB do
  def new do
    []
  end

  def add(db, timestamp, price)
      when is_list(db) and is_integer(timestamp) and is_integer(price) do
    [{timestamp, price} | db]
  end

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
