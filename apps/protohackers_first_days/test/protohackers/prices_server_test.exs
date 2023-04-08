defmodule Protohackers.PricesServerTest do
  use ExUnit.Case, async: true

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

  test "at least five simultaneous clients are supported" do
    0..50
    |> Enum.map(fn _ ->
      Task.async(fn ->
        {:ok, socket} = :gen_tcp.connect(~c"localhost", 5003, mode: :binary, active: false)
        :ok = :gen_tcp.send(socket, <<?I, 12345::32-signed-big, 101::32-signed-big>>)
        :ok = :gen_tcp.send(socket, <<?I, 12346::32-signed-big, 102::32-signed-big>>)
        :ok = :gen_tcp.send(socket, <<?I, 12347::32-signed-big, 100::32-signed-big>>)
        :ok = :gen_tcp.send(socket, <<?I, 40960::32-signed-big, 5::32-signed-big>>)
        :ok = :gen_tcp.send(socket, <<?Q, 12288::32-signed-big, 16384::32-signed-big>>)

        assert :gen_tcp.recv(socket, 0) == {:ok, <<101::32-signed-big>>}

        :ok = :gen_tcp.close(socket)
      end)
    end)
    |> Task.await_many()
  end
end
