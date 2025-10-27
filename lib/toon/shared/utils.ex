defmodule Toon.Utils do
  @moduledoc """
  Utility functions shared across TOON encoder and decoder.
  """

  @doc """
  Checks if a value is a primitive type (nil, boolean, number, or string).

  ## Examples

      iex> Toon.Utils.primitive?(nil)
      true

      iex> Toon.Utils.primitive?(42)
      true

      iex> Toon.Utils.primitive?("hello")
      true

      iex> Toon.Utils.primitive?(%{})
      false

      iex> Toon.Utils.primitive?([])
      false
  """
  @spec primitive?(term()) :: boolean()
  def primitive?(nil), do: true
  def primitive?(value) when is_boolean(value), do: true
  def primitive?(value) when is_number(value), do: true
  def primitive?(value) when is_binary(value), do: true
  def primitive?(_), do: false

  @doc """
  Checks if a value is a map (object).

  ## Examples

      iex> Toon.Utils.map?(%{})
      true

      iex> Toon.Utils.map?(%{"key" => "value"})
      true

      iex> Toon.Utils.map?([])
      false
  """
  @spec map?(term()) :: boolean()
  def map?(value) when is_map(value), do: true
  def map?(_), do: false

  @doc """
  Checks if a value is a list (array).

  ## Examples

      iex> Toon.Utils.list?([])
      true

      iex> Toon.Utils.list?([1, 2, 3])
      true

      iex> Toon.Utils.list?(%{})
      false
  """
  @spec list?(term()) :: boolean()
  def list?(value) when is_list(value), do: true
  def list?(_), do: false

  @doc """
  Checks if all elements in a list are primitives.

  ## Examples

      iex> Toon.Utils.all_primitives?([1, 2, 3])
      true

      iex> Toon.Utils.all_primitives?(["a", "b", "c"])
      true

      iex> Toon.Utils.all_primitives?([1, %{}, 3])
      false

      iex> Toon.Utils.all_primitives?([])
      true
  """
  @spec all_primitives?(list()) :: boolean()
  def all_primitives?(list) when is_list(list) do
    Enum.all?(list, &primitive?/1)
  end

  @doc """
  Checks if all elements in a list are maps.

  ## Examples

      iex> Toon.Utils.all_maps?([%{}, %{}])
      true

      iex> Toon.Utils.all_maps?([%{"a" => 1}, %{"b" => 2}])
      true

      iex> Toon.Utils.all_maps?([%{}, 1])
      false

      iex> Toon.Utils.all_maps?([])
      true
  """
  @spec all_maps?(list()) :: boolean()
  def all_maps?(list) when is_list(list) do
    Enum.all?(list, &map?/1)
  end

  @doc """
  Checks if all maps in a list have the same keys (for tabular format detection).

  ## Examples

      iex> Toon.Utils.same_keys?([%{"a" => 1}, %{"a" => 2}])
      true

      iex> Toon.Utils.same_keys?([%{"a" => 1, "b" => 2}, %{"a" => 3, "b" => 4}])
      true

      iex> Toon.Utils.same_keys?([%{"a" => 1}, %{"b" => 2}])
      false

      iex> Toon.Utils.same_keys?([])
      true
  """
  @spec same_keys?(list()) :: boolean()
  def same_keys?([]), do: true

  def same_keys?([first | rest]) when is_map(first) do
    first_keys = Map.keys(first) |> Enum.sort()

    Enum.all?(rest, fn map ->
      is_map(map) and Map.keys(map) |> Enum.sort() == first_keys
    end)
  end

  def same_keys?(_), do: false

  @doc """
  Repeats a string n times.

  ## Examples

      iex> Toon.Utils.repeat("  ", 0)
      ""

      iex> Toon.Utils.repeat("  ", 1)
      "  "

      iex> Toon.Utils.repeat("  ", 3)
      "      "
  """
  @spec repeat(String.t(), non_neg_integer()) :: String.t()
  def repeat(_string, 0), do: ""

  def repeat(string, times) when times > 0 do
    String.duplicate(string, times)
  end

  @doc """
  Normalizes a value for encoding, converting non-standard types to JSON-compatible ones.

  ## Examples

      iex> Toon.Utils.normalize(42)
      42

      iex> Toon.Utils.normalize(-0.0)
      0.0

      iex> Toon.Utils.normalize(:infinity)
      nil
  """
  @spec normalize(term()) :: Toon.Types.encodable()
  def normalize(nil), do: nil
  def normalize(value) when is_boolean(value), do: value
  def normalize(value) when is_binary(value), do: value

  def normalize(value) when is_number(value) do
    cond do
      # Handle negative zero
      value == 0 and :math.atan2(value, -1) == :math.pi() -> 0.0
      # Handle infinity and NaN
      not is_finite(value) -> nil
      true -> value
    end
  end

  def normalize(value) when is_list(value) do
    Enum.map(value, &normalize/1)
  end

  def normalize(value) when is_map(value) do
    Map.new(value, fn {k, v} ->
      {to_string(k), normalize(v)}
    end)
  end

  # Fallback for unsupported types
  def normalize(_value), do: nil

  # Private helper to check if a number is finite
  defp is_finite(value) when is_float(value) do
    # NaN check: NaN != NaN is the standard IEEE 754 way to detect NaN
    # credo:disable-for-lines:2
    is_nan = value != value
    # Infinity check: infinity is beyond maximum representable float
    is_inf = abs(value) > 1.0e308

    not is_nan and not is_inf
  end

  defp is_finite(value) when is_integer(value), do: true
end
