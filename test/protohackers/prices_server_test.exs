defmodule Protohackers.PricesServerTest do
  use ExUnit.Case

  test "handles queries" do
    {:ok, socket} = :gen_tcp.connect(~c"localhost", 5003, mode: :binary, active: false)

    :ok = :gen_tcp.send(socket, <<?I, 1000::32-signed-big, 1::32-signed-big>>)
    :ok = :gen_tcp.send(socket, <<?I, 2000::32-signed-big, 2::32-signed-big>>)
    :ok = :gen_tcp.send(socket, <<?I, 3000::32-signed-big, 3::32-signed-big>>)

    :ok = :gen_tcp.send(socket, <<?Q, 1000::32-signed-big, 3000::32-signed-big>>)
    assert {:ok, <<2::32-signed-big>>} = :gen_tcp.recv(socket, 4, 10_000)
  end

  test "handles clients separately" do
    {:ok, socket1} = :gen_tcp.connect(~c"localhost", 5003, mode: :binary, active: false)
    {:ok, socket2} = :gen_tcp.connect(~c"localhost", 5003, mode: :binary, active: false)

    :ok = :gen_tcp.send(socket1, <<?I, 1000::32-signed-big, 1::32-signed-big>>)
    :ok = :gen_tcp.send(socket2, <<?I, 2000::32-signed-big, 2::32-signed-big>>)

    :ok = :gen_tcp.send(socket1, <<?Q, 1000::32-signed-big, 3000::32-signed-big>>)
    assert {:ok, <<1::32-signed-big>>} = :gen_tcp.recv(socket1, 4, 10_000)

    :ok = :gen_tcp.send(socket2, <<?Q, 1000::32-signed-big, 3000::32-signed-big>>)
    assert {:ok, <<2::32-signed-big>>} = :gen_tcp.recv(socket2, 4, 10_000)
  end
end
