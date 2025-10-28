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

      iex> result = Toon.Encode.Arrays.encode_empty("items")
      iex> IO.iodata_to_binary(result)
      "items[0]:"
  """
  @spec encode_empty(String.t()) :: [iodata()]
  def encode_empty(key) do
    [[Strings.encode_key(key), "[0]", Constants.colon()]]
  end

  @doc """
  Encodes a primitive array in inline format.

  ## Examples

      iex> opts = %{delimiter: ",", length_marker: nil}
      iex> result = Toon.Encode.Arrays.encode_inline("tags", ["reading", "gaming"], opts)
      iex> IO.iodata_to_binary(result)
      "tags[2]: reading,gaming"
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

  Returns a list where the first element is the header, and subsequent elements
  are data rows (without indentation - indentation is added by the Writer).

  ## Examples

      iex> opts = %{delimiter: ",", length_marker: nil, indent_string: "  "}
      iex> users = [%{"name" => "Alice", "age" => 30}, %{"name" => "Bob", "age" => 25}]
      iex> [header | rows] = Toon.Encode.Arrays.encode_tabular("users", users, 0, opts)
      iex> IO.iodata_to_binary(header)
      "users[2]{age,name}:"
      iex> Enum.map(rows, &IO.iodata_to_binary/1)
      ["30,Alice", "25,Bob"]
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
    # Data rows will be indented by the Writer in Objects module
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

  Returns a list where the first element is the header, and subsequent elements
  are list items (without base indentation - indentation is added by the Writer).

  ## Examples

      iex> opts = %{delimiter: ",", length_marker: nil, indent_string: "  "}
      iex> items = [%{"title" => "Book", "price" => 9.99}, %{"title" => "Movie", "duration" => 120}]
      iex> [header | list_items] = Toon.Encode.Arrays.encode_list("items", items, 0, opts)
      iex> IO.iodata_to_binary(header)
      "items[2]:"
      iex> Enum.map(list_items, &IO.iodata_to_binary/1)
      ["- price: 9.99", "  title: Book", "- duration: 120", "  title: Movie"]
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
    # Indentation will be added by Writer in Objects module
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
    # Indentation will be added by Writer in Objects module
    extra_indent = if needs_marker, do: "", else: opts.indent_string

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
        [extra_indent | line]
      end

    [final_line]
  end

  # Encode list values
  defp encode_value_with_optional_marker(key, v, needs_marker, depth, opts) when is_list(v) do
    # Indentation will be added by Writer in Objects module
    nested = encode(key, v, depth + 1, opts)

    if needs_marker do
      [first_line | rest] = nested
      [
        [Constants.list_item_marker(), Constants.space(), first_line]
        | Enum.map(rest, fn line -> [opts.indent_string, line] end)
      ]
    else
      Enum.map(nested, fn line -> [opts.indent_string, line] end)
    end
  end

  # Encode map values
  defp encode_value_with_optional_marker(key, v, needs_marker, _depth, opts) when is_map(v) do
    # Indentation will be added by Writer in Objects module
    header = [key, Constants.colon()]

    nested_lines =
      v
      |> Enum.sort_by(fn {nk, _nv} -> nk end)
      |> Enum.map(fn {nk, nv} ->
        [opts.indent_string, encode_nested_primitive_or_placeholder(nk, nv, opts)]
      end)

    if needs_marker do
      [[Constants.list_item_marker(), Constants.space(), header] | nested_lines]
    else
      [[opts.indent_string, header] | nested_lines]
    end
  end

  # Fallback for unsupported types
  defp encode_value_with_optional_marker(key, _v, needs_marker, _depth, opts) do
    # Indentation will be added by Writer in Objects module
    extra_indent = if needs_marker, do: "", else: opts.indent_string

    line = [key, Constants.colon(), Constants.space(), Constants.null_literal()]

    final_line =
      if needs_marker do
        [Constants.list_item_marker(), Constants.space() | line]
      else
        [extra_indent | line]
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
