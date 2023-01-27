defmodule Protohackers.UDPServerTest do
  use ExUnit.Case, async: true

  test "insert and retrieve requests" do
    {:ok, socket} = :gen_udp.open(0, [:binary, active: false, recbuf: 1000])

    :ok = :gen_udp.send(socket, {127, 0, 0, 1}, 5005, "foo=1")
    :ok = :gen_udp.send(socket, {127, 0, 0, 1}, 5005, "foo")
    assert {:ok, {_address, _port, "foo=1"}} = :gen_udp.recv(socket, 0)

    :ok = :gen_udp.send(socket, {127, 0, 0, 1}, 5005, "foo=2")
    :ok = :gen_udp.send(socket, {127, 0, 0, 1}, 5005, "foo")
    assert {:ok, {_address, _port, "foo=2"}} = :gen_udp.recv(socket, 0)
  end

  test "version" do
    {:ok, socket} = :gen_udp.open(0, [:binary, active: false, recbuf: 1000])

    :ok = :gen_udp.send(socket, {127, 0, 0, 1}, 5005, "version=foo")
    :ok = :gen_udp.send(socket, {127, 0, 0, 1}, 5005, "version")

    assert {:ok, {_address, _port, "version=Protohackers in Elixir 1.0"}} =
             :gen_udp.recv(socket, 0)
  end
end
