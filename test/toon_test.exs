defmodule ToonTest do
  use ExUnit.Case, async: true

  doctest Toon

  describe "encode!/2" do
    test "encodes simple flat object" do
      data = %{"name" => "Alice", "age" => 30}
      result = Toon.encode!(data)

      assert result =~ "name: Alice"
      assert result =~ "age: 30"
    end

    test "encodes primitive array inline" do
      data = %{"tags" => ["elixir", "toon"]}
      result = Toon.encode!(data)

      assert result == "tags[2]: elixir,toon"
    end

    test "encodes nested object with indentation" do
      data = %{"user" => %{"name" => "Bob"}}
      result = Toon.encode!(data)

      assert result =~ "user:"
      assert result =~ "name: Bob"
    end

    test "encodes with custom delimiter" do
      data = %{"nums" => [1, 2, 3]}
      result = Toon.encode!(data, delimiter: "\t")

      assert result == "nums[3]: 1\t2\t3"
    end

    test "encodes with length marker" do
      data = %{"items" => ["a", "b"]}
      result = Toon.encode!(data, length_marker: "#")

      assert result == "items[#2]: a,b"
    end
  end

  describe "encode/2" do
    test "returns {:ok, result} on success" do
      data = %{"key" => "value"}
      assert {:ok, result} = Toon.encode(data)
      assert result == "key: value"
    end
  end

  describe "decode!/2" do
    test "decodes simple key-value" do
      result = Toon.decode!("name: Alice")
      assert result == %{"name" => "Alice"}
    end

    test "decodes multiple lines" do
      result = Toon.decode!("name: Alice\nage: 30")
      assert result == %{"name" => "Alice", "age" => 30}
    end

    test "decodes inline array" do
      result = Toon.decode!("tags[2]: a,b")
      assert result == %{"tags" => ["a", "b"]}
    end
  end
end
