defmodule Toon.RoundtripTest do
  use ExUnit.Case, async: true

  describe "encode -> decode roundtrip" do
    test "simple object" do
      original = %{"name" => "Alice", "age" => 30}
      encoded = Toon.encode!(original)
      decoded = Toon.decode!(encoded)

      assert decoded == original
    end

    test "primitive array" do
      original = %{"tags" => ["elixir", "toon", "llm"]}
      encoded = Toon.encode!(original)
      decoded = Toon.decode!(encoded)

      assert decoded == original
    end

    test "multiple key-value pairs" do
      original = %{
        "name" => "Bob",
        "age" => 25
      }

      encoded = Toon.encode!(original)
      decoded = Toon.decode!(encoded)

      assert decoded == original
    end

    test "mixed types" do
      original = %{
        "name" => "Bob",
        "age" => 25,
        "active" => true,
        "score" => 3.14,
        "tags" => ["a", "b"]
      }

      encoded = Toon.encode!(original)
      decoded = Toon.decode!(encoded)

      assert decoded == original
    end

    test "with custom delimiter" do
      original = %{"nums" => [1, 2, 3]}
      encoded = Toon.encode!(original, delimiter: "\t")
      decoded = Toon.decode!(encoded)

      assert decoded == original
    end

    test "empty array" do
      original = %{"items" => []}
      encoded = Toon.encode!(original)
      decoded = Toon.decode!(encoded)

      assert decoded == original
    end
  end
end
