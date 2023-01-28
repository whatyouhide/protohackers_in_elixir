defmodule LineReversal.UDPServerTest do
  use ExUnit.Case, async: true

  test "connecting and closing multiple clients" do
    {client1, session_id1} = open_udp()
    {client2, session_id2} = open_udp()

    udp_send(client1, "/connect/#{session_id1}/")
    udp_send(client2, "/connect/#{session_id2}/")

    assert udp_recv(client1) == "/ack/#{session_id1}/0/"
    assert udp_recv(client2) == "/ack/#{session_id2}/0/"

    # Closing

    udp_send(client1, "/close/#{session_id1}/")
    assert udp_recv(client1) == "/close/#{session_id1}/"

    udp_send(client2, "/close/#{session_id2}/")
    assert udp_recv(client2) == "/close/#{session_id2}/"
  end

  test "server ignores invalid messages" do
    {client, session_id} = open_udp()

    udp_send(client, "invalid")
    udp_send(client, "/connect/1")
    udp_send(client, "connect/1/")
    udp_send(client, "/ack/")
    udp_send(client, "//")

    # We can still connect after invalid messages
    udp_send(client, "/connect/#{session_id}/")
    assert udp_recv(client) == "/ack/#{session_id}/0/"
  end

  test "servers sends CLOSE if sending a packet to a dead client" do
    {client, session_id} = open_udp()

    # Connect
    udp_send(client, "/connect/#{session_id}/")
    assert udp_recv(client) == "/ack/#{session_id}/0/"

    # Close
    udp_send(client, "/close/#{session_id}/")
    assert udp_recv(client) == "/close/#{session_id}/"

    # Send a packet to a dead client and get another close message
    udp_send(client, "/data/#{session_id}/1/hello/")
    assert udp_recv(client) == "/close/#{session_id}/"
  end

  test "server receives data and sends the appropriate acks" do
    {client, session_id} = open_udp()

    # Connect
    udp_send(client, "/connect/#{session_id}/")
    assert udp_recv(client) == "/ack/#{session_id}/0/"

    # If we send a packet with invalid position (greater than 0 initially), we receive
    # an ack for 0.
    udp_send(client, "/data/#{session_id}/1/hello/")
    assert udp_recv(client) == "/ack/#{session_id}/0/"

    # Now we send real data at the right position, we should get the right ack.
    udp_send(client, "/data/#{session_id}/0/hello/")
    assert udp_recv(client) == "/ack/#{session_id}/5/"

    # If we send more data, we should get the right ack again.
    udp_send(client, "/data/#{session_id}/5/\\//")
    assert udp_recv(client) == "/ack/#{session_id}/6/"

    # If we send data with the wrong position, we get the ack for the last position.
    udp_send(client, "/data/#{session_id}/3/wrongpos/")
    assert udp_recv(client) == "/ack/#{session_id}/6/"
  end

  test "example session from the problem" do
    assert {:ok, client} = :gen_udp.open(0, [:binary, active: false])

    # Connect
    udp_send(client, "/connect/12345/")
    assert udp_recv(client) == "/ack/12345/0/"

    udp_send(client, "/data/12345/0/hello\n/")
    assert udp_recv(client) == "/ack/12345/6/"

    assert udp_recv(client) == "/data/12345/0/olleh\n/"
    udp_send(client, "/ack/12345/6/")

    udp_send(client, "/data/12345/6/Hello, world!\n/")
    assert udp_recv(client) == "/ack/12345/20/"

    assert udp_recv(client) == "/data/12345/6/!dlrow ,olleH\n/"

    udp_send(client, "/ack/12345/20/")

    udp_send(client, "/close/12345/")
    assert udp_recv(client) == "/close/12345/"
  end

  test "closing the same session multiple times" do
    {client, session_id} = open_udp()
    udp_send(client, "/connect/#{session_id}/")
    assert udp_recv(client) == "/ack/#{session_id}/0/"

    udp_send(client, "/close/#{session_id}/")
    assert udp_recv(client) == "/close/#{session_id}/"
    udp_send(client, "/close/#{session_id}/")
    assert udp_recv(client) == "/close/#{session_id}/"
  end

  test "data sent in broken packets" do
    {client, session_id} = open_udp()
    udp_send(client, "/connect/#{session_id}/")
    assert udp_recv(client) == "/ack/#{session_id}/0/"

    udp_send(client, "/data/#{session_id}/0/hello /")
    assert udp_recv(client) == "/ack/#{session_id}/6/"

    udp_send(client, "/data/#{session_id}/6/world!/")
    assert udp_recv(client) == "/ack/#{session_id}/12/"

    udp_send(client, "/data/#{session_id}/12/\\/\n/")
    assert udp_recv(client) == "/ack/#{session_id}/14/"

    assert udp_recv(client) == "/data/#{session_id}/0/\\/#{String.reverse("hello world!")}\n/"
  end

  test "multiple sessions in parallel" do
    tasks =
      for _ <- 1..20 do
        session_id = System.unique_integer([:positive])

        Task.async(fn ->
          assert {:ok, client} = :gen_udp.open(0, [:binary, active: false])
          udp_send(client, "/connect/#{session_id}/")
          assert udp_recv(client) == "/ack/#{session_id}/0/"

          udp_send(client, "/data/#{session_id}/0/hello\n/")
          assert udp_recv(client) == "/ack/#{session_id}/6/"

          assert udp_recv(client) == "/data/#{session_id}/0/olleh\n/"
          udp_send(client, "/ack/#{session_id}/6/")

          udp_send(client, "/close/#{session_id}/")
          assert udp_recv(client) == "/close/#{session_id}/"

          :done
        end)
      end

    assert Enum.all?(Task.yield_many(tasks, 5000), &match?({_task, {:ok, :done}}, &1))
  end

  test "multiple lines in a single UDP packet" do
    {client, session_id} = open_udp()
    udp_send(client, "/connect/#{session_id}/")
    assert udp_recv(client) == "/ack/#{session_id}/0/"

    udp_send(client, "/data/#{session_id}/0/abcd\n1234\nfoo/")
    assert udp_recv(client) == "/ack/#{session_id}/13/"

    assert udp_recv(client) == "/data/#{session_id}/0/dcba\n/"
    assert udp_recv(client) == "/data/#{session_id}/5/4321\n/"
  end

  test "sending and receiving big data" do
    {client, session_id} = open_udp()
    udp_send(client, "/connect/#{session_id}/")
    assert udp_recv(client) == "/ack/#{session_id}/0/"

    data_to_send = :binary.copy("a", 700)

    udp_send(client, "/data/#{session_id}/0/#{data_to_send}/")
    assert udp_recv(client) == "/ack/#{session_id}/700/"
    udp_send(client, "/data/#{session_id}/700/#{data_to_send}\n/")
    assert udp_recv(client) == "/ack/#{session_id}/1401/"

    assert udp_recv(client) == "/data/#{session_id}/0/#{:binary.copy("a", 971)}/"
    assert udp_recv(client) == "/data/#{session_id}/971/#{:binary.copy("a", 1400 - 971)}\n/"
  end

  @tag :capture_log
  test "server sends close message if clients misbehaves with acks and positions" do
    {client, session_id} = open_udp()
    udp_send(client, "/connect/#{session_id}/")
    assert udp_recv(client) == "/ack/#{session_id}/0/"

    len = String.length("either/or\n")

    udp_send(client, "/data/#{session_id}/0/either\\/or\n/")
    assert udp_recv(client) == "/ack/#{session_id}/#{len}/"

    assert udp_recv(client) == "/data/#{session_id}/0/ro\\/rehtie\n/"

    # Ack only two bytes, which means that the server should resend us the rest of the data.
    udp_send(client, "/ack/#{session_id}/2/")
    assert udp_recv(client) == "/data/#{session_id}/2/\\/rehtie\n/"

    # Ack another two bytes and let the server resend the rest.
    udp_send(client, "/ack/#{session_id}/3/")
    assert udp_recv(client) == "/data/#{session_id}/3/rehtie\n/"

    # If we ack something we already acked again, nothing happens.
    udp_send(client, "/ack/#{session_id}/1/")

    # If we hack further than what the server sent us, it's a protocol error.
    udp_send(client, "/ack/#{session_id}/1000/")
    assert udp_recv(client) == "/close/#{session_id}/"

    Process.sleep(100)
  end

  test "server retrasmits data if it doesn't receive acks" do
    {client, session_id} = open_udp()

    udp_send(client, "/connect/#{session_id}/")
    assert udp_recv(client) == "/ack/#{session_id}/0/"

    udp_send(client, "/data/#{session_id}/0/hello\n/")
    assert udp_recv(client) == "/ack/#{session_id}/6/"

    assert udp_recv(client) == "/data/#{session_id}/0/olleh\n/"
    assert udp_recv(client) == "/data/#{session_id}/0/olleh\n/"
    assert udp_recv(client) == "/data/#{session_id}/0/olleh\n/"

    udp_send(client, "/ack/#{session_id}/3/")
    assert udp_recv(client) == "/data/#{session_id}/3/eh\n/"
    assert udp_recv(client) == "/data/#{session_id}/3/eh\n/"
  end

  ## Helper

  defp open_udp do
    session_id = System.unique_integer([:positive])
    assert {:ok, socket} = :gen_udp.open(0, [:binary, active: false])
    {socket, session_id}
  end

  defp udp_recv(client) do
    assert {:ok, {_ip, _port, data}} = :gen_udp.recv(client, 0, 2_000)
    data
  end

  defp udp_send(client, data) do
    assert :ok = :gen_udp.send(client, {127, 0, 0, 1}, 5008, data)
  end
end
