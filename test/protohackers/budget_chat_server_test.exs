defmodule Protohackers.BudgetChatServerTest do
  use ExUnit.Case, async: true

  test "whole flow" do
    {:ok, socket1} =
      :gen_tcp.connect(~c"localhost", 5004, mode: :binary, active: false, packet: :line)

    {:ok, socket2} =
      :gen_tcp.connect(~c"localhost", 5004, mode: :binary, active: false, packet: :line)

    assert {:ok, "What's your username?\n"} = :gen_tcp.recv(socket1, 0, 5_000)
    :ok = :gen_tcp.send(socket1, "Sock1\n")
    assert {:ok, "* The room contains: \n"} = :gen_tcp.recv(socket1, 0, 5_000)

    assert {:ok, "What's your username?\n"} = :gen_tcp.recv(socket2, 0, 5_000)

    :ok = :gen_tcp.send(socket2, "Sock2\n")
    assert {:ok, "* The room contains: Sock1\n"} = :gen_tcp.recv(socket2, 0, 5_000)
    assert {:ok, "* Sock2 has entered the chat\n"} = :gen_tcp.recv(socket1, 0, 5_000)

    :ok = :gen_tcp.send(socket1, "Hello world!\n")
    assert {:ok, "[Sock1] Hello world!\n"} = :gen_tcp.recv(socket2, 0, 5_000)

    :ok = :gen_tcp.send(socket2, "Hi to you!\n")
    assert {:ok, "[Sock2] Hi to you!\n"} = :gen_tcp.recv(socket1, 0, 5_000)

    :gen_tcp.close(socket2)

    assert {:ok, "* Sock2 left\n"} = :gen_tcp.recv(socket1, 0, 5_000)

    {:ok, socket3} =
      :gen_tcp.connect(~c"localhost", 5004, mode: :binary, active: false, packet: :line)

    assert {:ok, "What's your username?\n"} = :gen_tcp.recv(socket3, 0, 5_000)
    :ok = :gen_tcp.send(socket3, "Sock3\n")
    assert {:ok, "* The room contains: Sock1\n"} = :gen_tcp.recv(socket3, 0, 5_000)
  end
end
