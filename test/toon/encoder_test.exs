defmodule Toon.EncoderTest do
  use ExUnit.Case, async: true

  alias Toon.Fixtures.{CustomDate, UserWithExcept}

  describe "fields_to_encode/2 with except option" do
    @user_attrs %{name: "Alice", email: "a@b.com", password: "secret"}

    test "excludes specified fields from encoding" do
      user = struct(UserWithExcept, @user_attrs)

      # Derived encoder now returns a normalized map
      encoded_map = Toon.Encoder.encode(user, [])

      assert Map.has_key?(encoded_map, "name") == true
      assert Map.has_key?(encoded_map, "email") == true
      assert Map.has_key?(encoded_map, "password") == false

      # Can still be encoded to TOON format
      toon_string = Toon.encode!(encoded_map)
      {:ok, decoded} = Toon.decode(toon_string)

      assert decoded == encoded_map
    end
  end

  describe "Toon.Utils.normalize/1 dispatches to Toon.Encoder for structs" do
    test "dispatches to explicit Toon.Encoder implementation" do
      date = %CustomDate{year: 2024, month: 1, day: 15}

      # Explicit encoder still returns iodata/string
      encoded_directly = date |> Toon.Encoder.encode([]) |> IO.iodata_to_binary()
      assert encoded_directly == "2024-01-15"

      # normalize/1 should produce identical output for explicit encoders
      assert Toon.Utils.normalize(date) == encoded_directly
    end

    test "dispatches to @derive Toon.Encoder" do
      user = %UserWithExcept{name: "Bob", email: "bob@test.com", password: "secret"}

      # Derived encoder returns normalized map
      encoded_map = Toon.Encoder.encode(user, [])

      # normalize/1 should produce identical output
      assert Toon.Utils.normalize(user) == encoded_map
      assert encoded_map == %{"name" => "Bob", "email" => "bob@test.com"}
    end
  end
end
