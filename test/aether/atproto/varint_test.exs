defmodule Aether.ATProto.VarintTest do
  use ExUnit.Case, async: true
  doctest Aether.ATProto.Varint

  alias Aether.ATProto.Varint

  describe "encode/1" do
    test "encodes small numbers" do
      assert Varint.encode(0) == <<0>>
      assert Varint.encode(1) == <<1>>
      assert Varint.encode(127) == <<127>>
    end

    test "encodes numbers requiring multiple bytes" do
      assert Varint.encode(128) == <<128, 1>>
      assert Varint.encode(300) == <<172, 2>>
      assert Varint.encode(16384) == <<128, 128, 1>>
    end

    test "encodes large numbers" do
      assert byte_size(Varint.encode(1_000_000)) > 2
      assert byte_size(Varint.encode(1_000_000_000)) > 4
    end
  end

  describe "decode/1" do
    test "decodes single-byte varints" do
      assert {:ok, 0, <<>>} = Varint.decode(<<0>>)
      assert {:ok, 1, <<>>} = Varint.decode(<<1>>)
      assert {:ok, 127, <<>>} = Varint.decode(<<127>>)
    end

    test "decodes multi-byte varints" do
      assert {:ok, 128, <<>>} = Varint.decode(<<128, 1>>)
      assert {:ok, 300, <<>>} = Varint.decode(<<172, 2>>)
      assert {:ok, 16384, <<>>} = Varint.decode(<<128, 128, 1>>)
    end

    test "returns remaining bytes" do
      assert {:ok, 127, <<99, 100>>} = Varint.decode(<<127, 99, 100>>)
      assert {:ok, 300, <<1, 2, 3>>} = Varint.decode(<<172, 2, 1, 2, 3>>)
    end

    test "returns error for incomplete varint" do
      assert {:error, :incomplete} = Varint.decode(<<128>>)
      assert {:error, :incomplete} = Varint.decode(<<>>)
    end
  end

  describe "round-trip encoding" do
    test "round-trips small numbers" do
      for n <- 0..1000 do
        encoded = Varint.encode(n)
        assert {:ok, ^n, <<>>} = Varint.decode(encoded)
      end
    end

    test "round-trips large numbers" do
      large_numbers = [
        10_000,
        100_000,
        1_000_000,
        10_000_000,
        100_000_000
      ]

      for n <- large_numbers do
        encoded = Varint.encode(n)
        assert {:ok, ^n, <<>>} = Varint.decode(encoded)
      end
    end

    test "round-trips edge cases" do
      edge_cases = [
        0,
        1,
        127,
        128,
        255,
        256,
        16383,
        16384
      ]

      for n <- edge_cases do
        encoded = Varint.encode(n)
        assert {:ok, ^n, <<>>} = Varint.decode(encoded)
      end
    end
  end
end
