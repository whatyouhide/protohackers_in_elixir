defmodule LineReversal.LRCP.ProtocolTest do
  use ExUnit.Case, async: true

  import LineReversal.LRCP.Protocol

  @max_int 2_147_483_648

  describe "parse_packet/1" do
    test "invalid packets" do
      assert parse_packet("") == :error
      assert parse_packet("/") == :error
      assert parse_packet("//") == :error
      assert parse_packet("/connect") == :error
      assert parse_packet("/connect/1") == :error
      assert parse_packet("connect/1/") == :error
    end

    test "returns an error for integers that are too large" do
      assert parse_packet("/connect/#{@max_int}/") == :error
      assert parse_packet("/ack/#{@max_int}/1/") == :error
      assert parse_packet("/ack/1/#{@max_int}/") == :error
    end

    test "connect packet" do
      assert parse_packet("/connect/231/") == {:ok, {:connect, 231}}
    end

    test "close packet" do
      assert parse_packet("/close/231/") == {:ok, {:close, 231}}
    end

    test "ack packet" do
      assert parse_packet("/ack/123/456/") == {:ok, {:ack, 123, 456}}
    end

    test "data packet" do
      assert parse_packet("/data/123/456/hello\\/world\\\\!\n/") ==
               {:ok, {:data, 123, 456, "hello\\/world\\\\!\n"}}
    end
  end
end
