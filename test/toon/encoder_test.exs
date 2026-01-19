defmodule Toon.EncoderTest do
  use ExUnit.Case, async: true

  alias Toon.Fixtures.UserWithExcept

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
end
