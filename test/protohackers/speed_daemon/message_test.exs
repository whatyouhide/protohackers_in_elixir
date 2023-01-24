defmodule Protohackers.SpeedDaemon.MessageTest do
  use ExUnit.Case, async: true

  alias Protohackers.SpeedDaemon.Message

  describe "encode/1 + decode/1 for all messages" do
    test "Plate" do
      message = %Message.Plate{plate: "UK43PKD", timestamp: 203_663}
      assert {:ok, ^message, ""} = Message.decode(Message.encode(message))
    end

    test "WantHeartbeat" do
      message = %Message.WantHeartbeat{interval: 1000}
      assert {:ok, ^message, ""} = Message.decode(Message.encode(message))
    end

    test "IAmDispatcher" do
      message = %Message.IAmDispatcher{roads: [582]}
      assert {:ok, ^message, ""} = Message.decode(Message.encode(message))
    end

    test "IAmCamera" do
      message = %Message.IAmCamera{road: 582, mile: 4452, limit: 100}
      assert {:ok, ^message, ""} = Message.decode(Message.encode(message))
    end

    test "Error" do
      message = %Message.Error{message: "Something went wrong"}
      assert {:ok, ^message, ""} = Message.decode(Message.encode(message))
    end

    test "Ticket" do
      message = %Message.Ticket{
        mile1: 4452,
        mile2: 4462,
        plate: "UK43PKD",
        road: 582,
        speed: 12000,
        timestamp1: 203_663,
        timestamp2: 203_963
      }

      assert {:ok, ^message, ""} = Message.decode(Message.encode(message))
    end

    test "Heartbeat" do
      message = %Message.Heartbeat{}
      assert {:ok, ^message, ""} = Message.decode(Message.encode(message))
    end
  end

  describe "decode/1" do
    test "returns :incomplete for valid-looking incomplete messages" do
      assert Message.decode(<<>>) == :incomplete
      assert Message.decode(<<0x20>>) == :incomplete
    end

    test "returns :error for invalid messages" do
      assert Message.decode(<<0x00>>) == :error
    end
  end
end
