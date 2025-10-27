defmodule Toon.Encode.IntegrationTest do
  use ExUnit.Case, async: true

  describe "TypeScript compatibility tests" do
    test "encodes primitives correctly" do
      assert Toon.encode!(nil) == "null"
      assert Toon.encode!(true) == "true"
      assert Toon.encode!(false) == "false"
      assert Toon.encode!(42) == "42"
      assert Toon.encode!(3.14) =~ "3.14"
    end

    test "encodes strings with appropriate quoting" do
      # Safe strings - no quotes
      assert Toon.encode!("hello") == "hello"
      assert Toon.encode!("Hello_World") == "Hello_World"

      # Empty string - requires quotes
      assert Toon.encode!("") == ~s("")

      # Strings with spaces - requires quotes
      assert Toon.encode!("hello world") == ~s("hello world")

      # Literals - requires quotes
      assert Toon.encode!("true") == ~s("true")
      assert Toon.encode!("false") == ~s("false")
      assert Toon.encode!("null") == ~s("null")

      # Numbers as strings - requires quotes
      assert Toon.encode!("42") == ~s("42")
      assert Toon.encode!("3.14") == ~s("3.14")
    end

    test "encodes flat objects" do
      result = Toon.encode!(%{"name" => "Alice", "age" => 30})
      assert result =~ "name: Alice"
      assert result =~ "age: 30"
    end

    test "encodes nested objects with indentation" do
      data = %{
        "user" => %{
          "name" => "Bob",
          "profile" => %{
            "bio" => "Developer"
          }
        }
      }

      result = Toon.encode!(data)
      assert result =~ "user:"
      assert result =~ "  name: Bob"
      assert result =~ "  profile:"
      assert result =~ "    bio: Developer"
    end

    test "encodes inline arrays" do
      result = Toon.encode!(%{"tags" => ["a", "b", "c"]})
      assert result == "tags[3]: a,b,c"
    end

    test "encodes with custom delimiters" do
      # Tab delimiter
      result = Toon.encode!(%{"nums" => [1, 2, 3]}, delimiter: "\t")
      assert result == "nums[3]: 1\t2\t3"

      # Pipe delimiter
      result = Toon.encode!(%{"items" => ["x", "y"]}, delimiter: "|")
      assert result == "items[2]: x|y"
    end

    test "encodes with length markers" do
      result = Toon.encode!(%{"data" => [1, 2]}, length_marker: "#")
      assert result == "data[#2]: 1,2"
    end

    test "encodes with custom indent" do
      data = %{"user" => %{"name" => "Charlie"}}
      result = Toon.encode!(data, indent: 4)
      assert result =~ "user:"
      assert result =~ "    name: Charlie"
    end

    test "encodes complex nested structure" do
      data = %{
        "id" => 123,
        "name" => "Project",
        "tags" => ["elixir", "toon"],
        "metadata" => %{
          "created" => "2025-01-01",
          "updated" => "2025-01-27"
        }
      }

      result = Toon.encode!(data)
      assert result =~ "id: 123"
      assert result =~ "name: Project"
      assert result =~ "tags[2]: elixir,toon"
      assert result =~ "metadata:"
      assert result =~ "  created:"
      assert result =~ "  updated:"
    end
  end
end
