defmodule Toon.Encode.Arrays do
  @moduledoc """
  Encoding of TOON arrays in three formats:
  - Inline: for primitive arrays (e.g., tags[2]: reading,gaming)
  - Tabular: for uniform object arrays (e.g., users[2]{name,age}: Alice,30 / Bob,25)
  - List: for mixed or non-uniform arrays
  """

  alias Toon.Constants
  alias Toon.Encode.{Primitives, Strings}
  alias Toon.Utils

  @doc """
  Encodes an array with the given key.

  Automatically detects the appropriate format based on array contents.
  """
  @spec encode(String.t(), list(), non_neg_integer(), map()) :: [iodata()]
  def encode(key, list, depth, opts) when is_list(list) do
    cond do
      Enum.empty?(list) ->
        encode_empty(key)

      Utils.all_primitives?(list) ->
        encode_inline(key, list, opts)

      Utils.all_maps?(list) and Utils.same_keys?(list) ->
        encode_tabular(key, list, depth, opts)

      true ->
        encode_list(key, list, depth, opts)
    end
  end

  @doc """
  Encodes an empty array.

  ## Examples

      iex> Toon.Encode.Arrays.encode_empty("items")
      ["items[0]:"]
  """
  @spec encode_empty(String.t()) :: [iodata()]
  def encode_empty(key) do
    [[Strings.encode_key(key), "[0]", Constants.colon()]]
  end

  @doc """
  Encodes a primitive array in inline format.

  ## Examples

      tags[2]: reading,gaming
  """
  @spec encode_inline(String.t(), list(), map()) :: [iodata()]
  def encode_inline(key, list, opts) do
    length_marker = format_length_marker(length(list), opts.length_marker)
    encoded_key = Strings.encode_key(key)

    values =
      list
      |> Enum.map(&Primitives.encode(&1, opts.delimiter))
      |> Enum.intersperse(opts.delimiter)

    header = [encoded_key, "[", length_marker, "]", Constants.colon(), Constants.space()]

    [[header, values]]
  end

  @doc """
  Encodes a uniform object array in tabular format.

  ## Examples

      users[2]{name,age}:
        Alice,30
        Bob,25
  """
  @spec encode_tabular(String.t(), list(), non_neg_integer(), map()) :: [iodata()]
  def encode_tabular(key, list, _depth, opts) do
    length_marker = format_length_marker(length(list), opts.length_marker)
    encoded_key = Strings.encode_key(key)

    # Get keys from first object (all objects have same keys)
    keys =
      case list do
        [first | _] -> Map.keys(first) |> Enum.sort()
        [] -> []
      end

    # Format header: key[N]{field1,field2,...}:
    fields = Enum.map(keys, &Strings.encode_key/1) |> Enum.intersperse(opts.delimiter)

    header = [
      encoded_key,
      "[",
      length_marker,
      "]",
      Constants.open_brace(),
      fields,
      Constants.close_brace(),
      Constants.colon()
    ]

    # Format data rows
    rows =
      Enum.map(list, fn obj ->
        values =
          keys
          |> Enum.map(fn k -> Map.get(obj, k) end)
          |> Enum.map(&Primitives.encode(&1, opts.delimiter))
          |> Enum.intersperse(opts.delimiter)

        values
      end)

    [header | rows]
  end

  @doc """
  Encodes an array in list format (for mixed or non-uniform arrays).

  ## Examples

      items[2]:
      - type: book
        title: "1984"
      - type: movie
        title: "Inception"
  """
  @spec encode_list(String.t(), list(), non_neg_integer(), map()) :: [iodata()]
  def encode_list(key, list, depth, opts) do
    length_marker = format_length_marker(length(list), opts.length_marker)
    encoded_key = Strings.encode_key(key)

    header = [encoded_key, "[", length_marker, "]", Constants.colon()]

    items =
      Enum.flat_map(list, fn item ->
        encode_list_item(item, depth, opts)
      end)

    [header | items]
  end

  # Private helpers

  defp format_length_marker(length, nil), do: Integer.to_string(length)
  defp format_length_marker(length, marker), do: marker <> Integer.to_string(length)

  defp encode_list_item(item, depth, opts) when is_map(item) do
    # Encode as indented object with list marker
    entries =
      item
      |> Enum.sort_by(fn {k, _v} -> k end)
      |> Enum.with_index()
      |> Enum.flat_map(fn {{k, v}, index} ->
        encode_map_entry_with_marker(k, v, index, depth, opts)
      end)

    entries
  end

  defp encode_list_item(item, _depth, opts) do
    # Primitive item in list
    [
      [
        Constants.list_item_marker(),
        Constants.space(),
        Primitives.encode(item, opts.delimiter)
      ]
    ]
  end

  # Helper for encoding map entries with list markers
  defp encode_map_entry_with_marker(k, v, index, depth, opts) do
    encoded_key = Strings.encode_key(k)
    needs_marker = index == 0

    encode_value_with_optional_marker(encoded_key, v, needs_marker, depth, opts)
  end

  # Encode primitive values
  defp encode_value_with_optional_marker(key, v, needs_marker, _depth, opts)
       when is_nil(v) or is_boolean(v) or is_number(v) or is_binary(v) do
    line = [
      key,
      Constants.colon(),
      Constants.space(),
      Primitives.encode(v, opts.delimiter)
    ]

    final_line =
      if needs_marker do
        [Constants.list_item_marker(), Constants.space() | line]
      else
        line
      end

    [final_line]
  end

  # Encode list values
  defp encode_value_with_optional_marker(key, v, needs_marker, depth, opts) when is_list(v) do
    nested = encode(key, v, depth + 1, opts)

    if needs_marker do
      [first_line | rest] = nested
      [[Constants.list_item_marker(), Constants.space(), first_line] | rest]
    else
      nested
    end
  end

  # Encode map values
  defp encode_value_with_optional_marker(key, v, needs_marker, _depth, opts) when is_map(v) do
    header = [key, Constants.colon()]

    nested_lines =
      v
      |> Enum.sort_by(fn {nk, _nv} -> nk end)
      |> Enum.map(fn {nk, nv} ->
        encode_nested_primitive_or_placeholder(nk, nv, opts)
      end)

    if needs_marker do
      [[Constants.list_item_marker(), Constants.space(), header] | nested_lines]
    else
      [header | nested_lines]
    end
  end

  # Fallback for unsupported types
  defp encode_value_with_optional_marker(key, _v, needs_marker, _depth, _opts) do
    line = [key, Constants.colon(), Constants.space(), Constants.null_literal()]

    final_line =
      if needs_marker do
        [Constants.list_item_marker(), Constants.space() | line]
      else
        line
      end

    [final_line]
  end

  # Helper for nested primitives
  defp encode_nested_primitive_or_placeholder(nk, nv, opts) do
    encoded_key = Strings.encode_key(nk)

    if Utils.primitive?(nv) do
      [
        encoded_key,
        Constants.colon(),
        Constants.space(),
        Primitives.encode(nv, opts.delimiter)
      ]
    else
      [encoded_key, Constants.colon(), Constants.space(), "..."]
    end
  end
end
