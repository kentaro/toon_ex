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
        encode_empty(key, opts.length_marker)

      Utils.all_primitives?(list) ->
        encode_inline(key, list, opts)

      Utils.all_maps?(list) and Utils.same_keys?(list) and can_be_tabular?(list) ->
        encode_tabular(key, list, depth, opts)

      true ->
        encode_list(key, list, depth, opts)
    end
  end

  # Check if array of objects can be encoded in tabular format
  # Tabular format requires all values to be primitives
  defp can_be_tabular?(list) do
    Enum.all?(list, fn obj ->
      Enum.all?(obj, fn {_k, v} -> Utils.primitive?(v) end)
    end)
  end

  @doc """
  Encodes an empty array.

  ## Examples

      iex> result = Toon.Encode.Arrays.encode_empty("items", nil)
      iex> IO.iodata_to_binary(result)
      "items[0]:"
  """
  @spec encode_empty(String.t(), String.t() | nil) :: [iodata()]
  def encode_empty(key, length_marker \\ nil) do
    marker = format_length_marker(0, length_marker)
    [[Strings.encode_key(key), "[", marker, "]", Constants.colon()]]
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

    # Include delimiter marker in header per TOON spec Section 6
    delimiter_marker = if opts.delimiter != ",", do: opts.delimiter, else: ""

    header = [
      encoded_key,
      "[",
      length_marker,
      delimiter_marker,
      "]",
      Constants.colon(),
      Constants.space()
    ]

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

    # Get keys from first object and use provided key order or sort alphabetically
    keys =
      case list do
        [first | _] ->
          map_keys = Map.keys(first)

          key_order = Map.get(opts, :key_order)

          # Use key_order if provided and matches all keys
          if is_list(key_order) and not Enum.empty?(key_order) do
            ordered = Enum.filter(key_order, &(&1 in map_keys))

            if length(ordered) == length(map_keys) do
              ordered
            else
              Enum.sort(map_keys)
            end
          else
            Enum.sort(map_keys)
          end

        [] ->
          []
      end

    # Format header: key[N]{field1,field2,...}: or key[N\t]{...}: per TOON spec
    fields = Enum.map(keys, &Strings.encode_key/1) |> Enum.intersperse(opts.delimiter)
    delimiter_marker = if opts.delimiter != ",", do: opts.delimiter, else: ""

    header = [
      encoded_key,
      "[",
      length_marker,
      delimiter_marker,
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
      iex> items = [%{"title" => "Book", "price" => 9}, %{"title" => "Movie", "duration" => 120}]
      iex> [header | list_items] = Toon.Encode.Arrays.encode_list("items", items, 0, opts)
      iex> IO.iodata_to_binary(header)
      "items[2]:"
      iex> Enum.map(list_items, &IO.iodata_to_binary/1)
      ["- price: 9", "  title: Book", "- duration: 120", "  title: Movie"]
  """
  @spec encode_list(String.t(), list(), non_neg_integer(), map()) :: [iodata()]
  def encode_list(key, list, depth, opts) do
    length_marker = format_length_marker(length(list), opts.length_marker)
    encoded_key = Strings.encode_key(key)
    delimiter_marker = if opts.delimiter != ",", do: opts.delimiter, else: ""

    header = [encoded_key, "[", length_marker, delimiter_marker, "]", Constants.colon()]

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
    # Encode as indented object with list marker, using key order if provided
    map_keys = Map.keys(item)

    key_order = Map.get(opts, :key_order)

    # For list items, if key_order is provided, use it as a reference order
    # Keys from the item that appear in key_order come first (in key_order's sequence),
    # followed by any additional keys in the item (sorted)
    keys =
      if is_list(key_order) and not Enum.empty?(key_order) do
        # Keys that are in both key_order and map_keys, in key_order's sequence
        ordered_keys = Enum.filter(key_order, &(&1 in map_keys))
        # Keys in map_keys but not in key_order, sorted
        extra_keys = Enum.filter(map_keys, &(&1 not in key_order)) |> Enum.sort()
        # Combine: ordered keys first, then extra keys
        ordered_keys ++ extra_keys
      else
        Enum.sort(map_keys)
      end

    # Use the keys as-is - they already have the correct order from key_order or sorted
    # The key order extraction from JSON preserves the original field order
    entries =
      keys
      |> Enum.with_index()
      |> Enum.flat_map(fn {k, index} ->
        v = Map.get(item, k)
        encode_map_entry_with_marker(k, v, index, depth, opts)
      end)

    entries
  end

  defp encode_list_item(item, _depth, opts) when is_list(item) do
    # Array item in list - encode as inline array
    # Format: - [N]: val1,val2,val3
    cond do
      Enum.empty?(item) ->
        # Empty array
        length_marker = format_length_marker(0, opts.length_marker)
        [[Constants.list_item_marker(), Constants.space(), "[", length_marker, "]:"]]

      Utils.all_primitives?(item) ->
        # Inline array of primitives
        length_marker = format_length_marker(length(item), opts.length_marker)
        delimiter_marker = if opts.delimiter != ",", do: opts.delimiter, else: ""

        values =
          item
          |> Enum.map(&Primitives.encode(&1, opts.delimiter))
          |> Enum.intersperse(opts.delimiter)

        [
          [
            Constants.list_item_marker(),
            Constants.space(),
            "[",
            length_marker,
            delimiter_marker,
            "]",
            Constants.colon(),
            Constants.space(),
            values
          ]
        ]

      true ->
        # Complex array - encode as nested list
        # Format: - key[N]:
        #           - item1
        #           - item2
        length_marker = format_length_marker(length(item), opts.length_marker)
        delimiter_marker = if opts.delimiter != ",", do: opts.delimiter, else: ""

        header = [
          Constants.list_item_marker(),
          Constants.space(),
          "[",
          length_marker,
          delimiter_marker,
          "]",
          Constants.colon()
        ]

        nested_items =
          Enum.flat_map(item, fn nested_item ->
            # Recursively encode nested items with extra indentation
            nested = encode_list_item(nested_item, 0, opts)

            Enum.map(nested, fn line ->
              [opts.indent_string | line]
            end)
          end)

        [header | nested_items]
    end
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
    # Check if this is an array of arrays (all elements are lists)
    cond do
      # Empty array
      Enum.empty?(v) ->
        length_marker = format_length_marker(0, opts.length_marker)
        line = [Strings.encode_key(key), "[", length_marker, "]", Constants.colon()]

        if needs_marker do
          [[Constants.list_item_marker(), Constants.space() | line]]
        else
          [[opts.indent_string | line]]
        end

      # Array of primitives - use inline format on the hyphen line
      Utils.all_primitives?(v) ->
        length_marker = format_length_marker(length(v), opts.length_marker)
        delimiter_marker = if opts.delimiter != ",", do: opts.delimiter, else: ""

        values =
          v
          |> Enum.map(&Primitives.encode(&1, opts.delimiter))
          |> Enum.intersperse(opts.delimiter)

        line = [
          Strings.encode_key(key),
          "[",
          length_marker,
          delimiter_marker,
          "]",
          Constants.colon(),
          Constants.space(),
          values
        ]

        if needs_marker do
          [[Constants.list_item_marker(), Constants.space() | line]]
        else
          [[opts.indent_string | line]]
        end

      # Complex array (contains objects, arrays, or mixed) - use full array format
      true ->
        # Check if this is a tabular or list array format
        is_tabular =
          Utils.all_maps?(v) and Utils.same_keys?(v) and
            Enum.all?(v, fn obj -> Enum.all?(obj, fn {_k, val} -> Utils.primitive?(val) end) end)

        # Check if this is a list array (non-uniform objects or has nested values)
        is_list_array =
          Utils.all_maps?(v) and
            (not Utils.same_keys?(v) or
               Enum.any?(v, fn obj ->
                 Enum.any?(obj, fn {_k, val} -> not Utils.primitive?(val) end)
               end))

        cond do
          is_tabular ->
            # Tabular format: data rows need extra indentation relative to header
            [header | data_rows] = encode(key, v, depth + 1, opts)

            header_line =
              if needs_marker do
                [Constants.list_item_marker(), Constants.space(), header]
              else
                [opts.indent_string, header]
              end

            # Data rows get double indentation (base + 1 level)
            data_lines =
              Enum.map(data_rows, fn row -> [opts.indent_string, opts.indent_string, row] end)

            [header_line | data_lines]

          is_list_array ->
            # List format: header, then list items with extra indentation
            [header | list_items] = encode(key, v, depth + 1, opts)

            header_line =
              if needs_marker do
                [Constants.list_item_marker(), Constants.space(), header]
              else
                [opts.indent_string, header]
              end

            # List items get double indentation (they already have depth+1 indent, add one more)
            item_lines =
              Enum.map(list_items, fn line -> [opts.indent_string, opts.indent_string, line] end)

            [header_line | item_lines]

          true ->
            # Other array types (arrays of arrays, etc.)
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
    end
  end

  # Encode map values
  defp encode_value_with_optional_marker(key, v, needs_marker, depth, opts) when is_map(v) do
    # Nested object - delegate to main encoder
    header_line = [key, Constants.colon()]

    # Use the main encoder's do_encode function for nested map
    nested_result =
      Toon.Encode.do_encode(v, depth + 1, opts)
      |> IO.iodata_to_binary()
      |> String.split("\n")
      |> Enum.map(&[opts.indent_string, &1])

    if needs_marker do
      [[Constants.list_item_marker(), Constants.space(), header_line] | nested_result]
    else
      [[opts.indent_string, header_line] | nested_result]
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
end
