defmodule Toon.Generators do
  @moduledoc """
  StreamData generators for property-based testing.
  """

  import StreamData

  @doc """
  Generates encodable Elixir data structures.
  """
  def encodable_data do
    encodable_data(3)
  end

  defp encodable_data(0), do: primitive_value()

  defp encodable_data(depth) do
    frequency([
      {5, primitive_value()},
      {1, map_of(safe_string(), encodable_data(depth - 1), max_length: 3)},
      {1, list_of(encodable_data(depth - 1), max_length: 5)}
    ])
  end

  @doc """
  Generates primitive values (nil, boolean, number, string).
  """
  def primitive_value do
    one_of([
      constant(nil),
      boolean(),
      integer(),
      float(),
      safe_string(),
      string(:alphanumeric, max_length: 20)
    ])
  end

  @doc """
  Generates safe strings that don't need quoting.
  """
  def safe_string do
    string([?a..?z, ?A..?Z, ?0..?9, ?_], min_length: 1, max_length: 15)
  end

  @doc """
  Generates composite values (maps and lists).
  """
  def composite_value(leaf_generator) do
    one_of([
      # Map with string keys
      map_of(safe_string(), leaf_generator, max_length: 5),
      # List
      list_of(leaf_generator, max_length: 10),
      # Primitive list (all same type)
      list_of(primitive_value(), max_length: 8)
    ])
  end
end
