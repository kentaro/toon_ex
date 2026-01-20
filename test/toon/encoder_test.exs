defmodule Toon.EncoderTest do
  use ExUnit.Case, async: true

  alias Toon.Fixtures.{CustomDate, UserWithExcept}

  describe "fields_to_encode/2 with except option" do
    @user_attrs %{name: "Alice", email: "a@b.com", password: "secret"}

    test "excludes specified fields from encoding" do
      user = struct(UserWithExcept, @user_attrs)

      encoded = user |> Toon.Encoder.encode([]) |> IO.iodata_to_binary()
      {:ok, decoded} = Toon.decode(encoded)

      assert Map.has_key?(decoded, "name") == true
      assert Map.has_key?(decoded, "email") == true
      assert Map.has_key?(decoded, "password") == false
    end
  end

  describe "Toon.Utils.normalize/1 dispatches to Toon.Encoder for structs" do
    test "dispatches to explicit Toon.Encoder implementation" do
      date = %CustomDate{year: 2024, month: 1, day: 15}

      # Direct encoder call
      encoded_directly = date |> Toon.Encoder.encode([]) |> IO.iodata_to_binary()

      # normalize/1 should produce identical output
      assert Toon.Utils.normalize(date) == encoded_directly
    end

    test "dispatches to @derive Toon.Encoder" do
      user = %UserWithExcept{name: "Bob", email: "bob@test.com", password: "secret"}

      # Direct encoder call
      encoded_directly = user |> Toon.Encoder.encode([]) |> IO.iodata_to_binary()

      # normalize/1 should produce identical output
      assert Toon.Utils.normalize(user) == encoded_directly
    end
  end
end
