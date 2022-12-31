defmodule ProtohackersTest do
  use ExUnit.Case
  doctest Protohackers

  test "greets the world" do
    assert Protohackers.hello() == :world
  end
end
