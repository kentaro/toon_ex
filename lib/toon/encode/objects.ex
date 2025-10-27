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
  @spec encode(map(), non_neg_integer(), map()) :: iodata()
  def encode(map, depth, opts) when is_map(map) do
    writer = Writer.new(opts.indent)

    writer =
      map
      |> Enum.sort_by(fn {k, _v} -> k end)
      |> Enum.reduce(writer, fn {key, value}, acc ->
        encode_entry(acc, key, value, depth, opts)
      end)

    Writer.to_iodata(writer)
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

  defp append_lines(writer, [], _depth), do: writer

  defp append_lines(writer, lines, depth) when is_list(lines) do
    Enum.reduce(lines, writer, fn line, acc ->
      Writer.push(acc, line, depth)
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
