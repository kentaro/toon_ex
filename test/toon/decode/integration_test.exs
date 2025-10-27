defmodule Toon.Decode.IntegrationTest do
  use ExUnit.Case, async: true

  describe "decode integration tests" do
    test "decodes primitive values in objects" do
      assert Toon.decode!("value: null") == %{"value" => nil}
      assert Toon.decode!("flag: true") == %{"flag" => true}
      assert Toon.decode!("enabled: false") == %{"enabled" => false}
      assert Toon.decode!("count: 42") == %{"count" => 42}
      assert Toon.decode!("pi: 3.14") == %{"pi" => 3.14}
      assert Toon.decode!("text: hello") == %{"text" => "hello"}
    end

    test "decodes quoted string values" do
      # Quoted strings are handled by NimbleParsec - quotes are removed during parsing
      result = Toon.decode!(~s(msg: "hello world"))
      assert result["msg"] == "hello world"
    end

    test "decodes simple objects" do
      result = Toon.decode!("name: Alice\nage: 30")
      assert result == %{"name" => "Alice", "age" => 30}
    end

    test "decodes inline arrays" do
      result = Toon.decode!("tags[3]: a,b,c")
      assert result == %{"tags" => ["a", "b", "c"]}
    end

    test "decodes with tab delimiter" do
      result = Toon.decode!("nums[3]: 1\t2\t3")
      assert result == %{"nums" => [1, 2, 3]}
    end

    test "decodes empty arrays" do
      result = Toon.decode!("items[0]:")
      assert result == %{"items" => []}
    end

    test "decodes with length markers" do
      result = Toon.decode!("data[#2]: 1,2")
      assert result == %{"data" => [1, 2]}
    end

    test "decodes keys as atoms when specified" do
      result = Toon.decode!("name: Alice", keys: :atoms)
      assert result == %{name: "Alice"}
    end

    test "decodes complex multiline objects" do
      toon = """
      id: 123
      name: Project
      active: true
      tags[2]: elixir,toon
      """

      result = Toon.decode!(toon)

      assert result == %{
               "id" => 123,
               "name" => "Project",
               "active" => true,
               "tags" => ["elixir", "toon"]
             }
    end
  end

  describe "decode error handling" do
    test "returns error for invalid TOON" do
      assert {:error, %Toon.DecodeError{}} = Toon.decode("invalid: : syntax")
    end

    test "raises on decode! with invalid input" do
      assert_raise Toon.DecodeError, fn ->
        Toon.decode!("invalid: : syntax")
      end
    end
  end
end
