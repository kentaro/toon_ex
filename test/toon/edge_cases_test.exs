defmodule Toon.EdgeCasesTest do
  @moduledoc """
  Tests for edge cases to ensure behavior is preserved after removing dead code.
  """
  use ExUnit.Case, async: true

  describe "empty input decoding" do
    test "empty string decodes to empty map" do
      assert {:ok, %{}} = Toon.decode("")
    end

    test "whitespace-only string decodes to empty map" do
      assert {:ok, %{}} = Toon.decode("   ")
      assert {:ok, %{}} = Toon.decode("\n\n")
      assert {:ok, %{}} = Toon.decode("  \n  \n  ")
    end
  end

  describe "empty data encoding" do
    test "empty map encodes to empty string" do
      assert "" = Toon.encode!(%{})
    end

    test "empty list encodes with zero-length header" do
      result = Toon.encode!(%{"items" => []})
      assert result =~ "items[0]:"
    end

    test "nested empty structures" do
      # Empty map inside map - produces key with colon
      assert "nested:" = Toon.encode!(%{"nested" => %{}})

      # Empty list inside map
      result = Toon.encode!(%{"items" => []})
      assert result =~ "[0]:"
    end
  end

  describe "decode and encode roundtrip for edge cases" do
    test "empty map roundtrip" do
      original = %{}
      encoded = Toon.encode!(original)
      {:ok, decoded} = Toon.decode(encoded)
      assert decoded == original
    end
  end
end
