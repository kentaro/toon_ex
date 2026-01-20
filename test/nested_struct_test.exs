defmodule Toon.NestedStructTest do
  use ExUnit.Case, async: true

  alias Toon.Fixtures.{Person, Company}

  describe "nested struct encoding" do
    test "encodes and decodes nested structs correctly" do
      person = %Person{name: "John", age: 30}
      company = %Company{name: "Acme", ceo: person}

      # Encode the nested struct
      encoded = Toon.encode!(company)

      # Should produce TOON format
      assert is_binary(encoded)

      # Decode and verify
      {:ok, decoded} = Toon.decode(encoded)

      # Verify structure
      assert decoded["name"] == "Acme"
      assert decoded["ceo"]["name"] == "John"
      assert decoded["ceo"]["age"] == 30
    end

    test "normalizes nested structs to maps" do
      person = %Person{name: "Jane", age: 25}
      company = %Company{name: "TechCo", ceo: person}

      # normalize should convert nested structs to maps
      normalized = Toon.Utils.normalize(company)

      assert is_map(normalized)
      assert normalized["name"] == "TechCo"
      assert is_map(normalized["ceo"])
      assert normalized["ceo"]["name"] == "Jane"
      assert normalized["ceo"]["age"] == 25
    end

    test "handles deeply nested structs" do
      person1 = %Person{name: "Alice", age: 35}
      company1 = %Company{name: "StartupA", ceo: person1}

      person2 = %Person{name: "Bob", age: 40}
      company2 = %Company{name: "StartupB", ceo: person2}

      # Create a list of companies (testing nested structs in lists)
      data = %{"companies" => [company1, company2]}

      encoded = Toon.encode!(data)
      {:ok, decoded} = Toon.decode(encoded)

      assert length(decoded["companies"]) == 2
      assert decoded["companies"] |> Enum.at(0) |> Map.get("name") == "StartupA"
      assert decoded["companies"] |> Enum.at(0) |> Map.get("ceo") |> Map.get("name") == "Alice"
      assert decoded["companies"] |> Enum.at(1) |> Map.get("name") == "StartupB"
      assert decoded["companies"] |> Enum.at(1) |> Map.get("ceo") |> Map.get("name") == "Bob"
    end
  end
end
