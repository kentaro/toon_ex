defmodule Toon.Encode.PrimitivesTest do
  use ExUnit.Case, async: true

  alias Toon.Encode.Primitives

  describe "encode/2" do
    test "encodes nil as null" do
      assert Primitives.encode(nil, ",") == "null"
    end

    test "encodes boolean values" do
      assert Primitives.encode(true, ",") == "true"
      assert Primitives.encode(false, ",") == "false"
    end

    test "encodes integers" do
      assert Primitives.encode(0, ",") == "0"
      assert Primitives.encode(42, ",") == "42"
      assert Primitives.encode(-100, ",") == "-100"
    end

    test "encodes floats" do
      result = Primitives.encode(3.14, ",")
      assert is_binary(result)
      assert result =~ "3.14"
    end

    test "encodes safe strings without quotes" do
      assert Primitives.encode("hello", ",") == "hello"
      assert Primitives.encode("Hello_World", ",") == "Hello_World"
    end

    test "encodes strings with spaces using quotes" do
      result = Primitives.encode("hello world", ",") |> IO.iodata_to_binary()
      assert result == ~s("hello world")
    end
  end
end
