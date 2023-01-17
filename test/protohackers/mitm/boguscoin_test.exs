defmodule Protohackers.MIMT.BoguscoinTest do
  use ExUnit.Case, async: true

  alias Protohackers.MITM.Boguscoin

  @tonys_address "7YWHMfk9JZe0LM0g1ZauHuiSxhI"

  @sample_addresses [
    "7F1u3wSD5RbOHQmupo9nx4TnhQ",
    "7iKDZEwPZSqIvDnHvVN2r0hUWXD5rHX",
    "7LOrwbDlS8NujgjddyogWgIM93MV5N2VR",
    "7adNeSwJkMakpEcln9HEtthSRtxdmEHOT8T"
  ]

  describe "rewrite_addresses/1" do
    test "doesn't do anything if there are no addresses" do
      assert Boguscoin.rewrite_addresses("hello") == "hello"
    end

    test "ignores too-long addresses" do
      str = "This is too long: 7xtGNgS2V2d32VsCXYpZSdQXOY4Iy7vlVboZ"
      assert Boguscoin.rewrite_addresses(str) == str
    end

    test "ignores suspicious addresses" do
      str = "Not Boguscoin: 7cuyhvvuR2kduZsmZNmBqmUJpZTjMDbhtsD-PI1NrEdUAZ8Ar5NX0DUTdCUEo55V-1234"

      assert Boguscoin.rewrite_addresses(str) == str
    end

    test "multiple addresses" do
      assert Boguscoin.rewrite_addresses(Enum.join(@sample_addresses, " ")) ==
               Enum.join(
                 List.duplicate(
                   @tonys_address,
                   length(@sample_addresses)
                 ),
                 " "
               )
    end

    test "with sample addresses" do
      for address <- @sample_addresses do
        assert Boguscoin.rewrite_addresses(address) == @tonys_address
        assert Boguscoin.rewrite_addresses(address <> " foo") == @tonys_address <> " foo"
        assert Boguscoin.rewrite_addresses("foo " <> address) == "foo " <> @tonys_address

        assert Boguscoin.rewrite_addresses("foo " <> address <> " bar") ==
                 "foo " <> @tonys_address <> " bar"
      end
    end
  end
end
