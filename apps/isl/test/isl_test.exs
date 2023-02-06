defmodule ISLTest do
  use ExUnit.Case, async: true

  test "example session from the problem description" do
    {:ok, client} = :gen_tcp.connect(~c"localhost", 5009, [:binary, active: true])

    :ok = :gen_tcp.send(client, <<0x02, 0x7B, 0x05, 0x01, 0x00>>)

    :ok =
      :gen_tcp.send(
        client,
        <<0xF2, 0x20, 0xBA, 0x44, 0x18, 0x84, 0xBA, 0xAA, 0xD0, 0x26, 0x44, 0xA4, 0xA8, 0x7E>>
      )

    assert_receive {:tcp, ^client, <<0x72, 0x20, 0xBA, 0xD8, 0x78, 0x70, 0xEE>>}, 500

    :ok =
      :gen_tcp.send(
        client,
        <<0x6A, 0x48, 0xD6, 0x58, 0x34, 0x44, 0xD6, 0x7A, 0x98, 0x4E, 0x0C, 0xCC, 0x94, 0x31>>
      )

    assert_receive {:tcp, ^client, <<0xF2, 0xD0, 0x26, 0xC8, 0xA4, 0xD8, 0x7E>>}, 500
  end

  @tag :capture_log
  test "no-op ciphers result in the client being disconnected" do
    {:ok, client} = :gen_tcp.connect(~c"localhost", 5009, [:binary, active: true])

    # Cipher spec from the problem description
    :ok = :gen_tcp.send(client, <<0x02, 0xA0, 0x02, 0x0B, 0x02, 0xAB, 0x00>>)

    assert_receive {:tcp_closed, ^client}
  end
end
