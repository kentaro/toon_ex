defmodule Toon.Encode.Objects do
  @moduledoc """
  Encoding of TOON objects (maps).
  """

  alias Toon.Constants
  alias Toon.Encode.{Arrays, Primitives, Strings, Writer}
  alias Toon.Utils

  @doc """
  Encodes a map to TOON format.

  ## Examples

      iex> opts = %{indent: 2, delimiter: ",", length_marker: nil}
      iex> map = %{"name" => "Alice", "age" => 30}
      iex> Toon.Encode.Objects.encode(map, 0, opts)

  """
  @spec encode(map(), non_neg_integer(), map()) :: [iodata()]
  def encode(map, depth, opts) when is_map(map) do
    writer = Writer.new(opts.indent)

    # Get the keys in the correct order
    keys = get_ordered_keys(map, Map.get(opts, :key_order), [])

    writer =
      keys
      |> Enum.reduce(writer, fn key, acc ->
        value = Map.get(map, key)
        encode_entry(acc, key, value, depth, opts)
      end)

    Writer.to_iodata(writer)
  end

  # Get keys in the correct order based on key_order option
  defp get_ordered_keys(map, key_order, path) do
    cond do
      # If we have key order information for this path, use it
      is_map(key_order) and Map.has_key?(key_order, path) ->
        ordered = Map.get(key_order, path)
        # Filter to only include keys that exist in the map
        Enum.filter(ordered, &Map.has_key?(map, &1))

      # If key_order is a list (simple case) and this is the root level, use it
      is_list(key_order) and not Enum.empty?(key_order) and path == [] ->
        # Filter to only include keys that exist in the map and match the order
        existing_keys = Map.keys(map)
        ordered_existing = Enum.filter(key_order, &(&1 in existing_keys))

        # If all keys are in the order list, use it; otherwise fallback to sorted
        if length(ordered_existing) == length(existing_keys) do
          ordered_existing
        else
          Enum.sort(existing_keys)
        end

      # If key_order is nil or not applicable, sort keys alphabetically for consistent output
      true ->
        Map.keys(map) |> Enum.sort()
    end
  end

  @doc """
  Encodes a single key-value pair.
  """
  @spec encode_entry(Writer.t(), String.t(), term(), non_neg_integer(), map()) :: Writer.t()
  def encode_entry(writer, key, value, depth, opts) do
    encoded_key = Strings.encode_key(key)

    cond do
      Utils.primitive?(value) ->
        # Inline format: key: value
        line = [
          encoded_key,
          Constants.colon(),
          Constants.space(),
          Primitives.encode(value, opts.delimiter)
        ]

        Writer.push(writer, line, depth)

      Utils.list?(value) ->
        # Delegate to Arrays module
        array_lines = Arrays.encode(key, value, depth, opts)
        append_lines(writer, array_lines, depth)

      Utils.map?(value) ->
        # Nested object
        header = [encoded_key, Constants.colon()]
        writer = Writer.push(writer, header, depth)

        nested_lines = encode(value, depth + 1, opts)
        append_iodata(writer, nested_lines, depth + 1)

      true ->
        # Unsupported type, encode as null
        line = [encoded_key, Constants.colon(), Constants.space(), Constants.null_literal()]
        Writer.push(writer, line, depth)
    end
  end

  # Private helpers

  defp append_lines(writer, [header | data_rows], depth) do
    # For arrays, the first line is the header at current depth
    # Subsequent lines (data rows for tabular format) should be one level deeper
    writer = Writer.push(writer, header, depth)

    Enum.reduce(data_rows, writer, fn row, acc ->
      Writer.push(acc, row, depth + 1)
    end)
  end

  defp append_iodata(writer, iodata, _base_depth) do
    # Convert iodata to string, split by lines, and add to writer
    iodata
    |> IO.iodata_to_binary()
    |> String.split("\n")
    |> Enum.reduce(writer, fn line, acc ->
      # Lines from nested encode already have relative indentation,
      # but we need to add them without additional depth since encode()
      # already handles depth
      if line == "" do
        acc
      else
        # Extract existing indentation and preserve it
        Writer.push(acc, line, 0)
      end
    end)
  end
end
