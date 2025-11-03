defmodule Toon.Encode do
  @moduledoc """
  Main encoder for TOON format.

  This module coordinates the encoding process, dispatching to specialized
  encoders based on the type of value being encoded.
  """

  alias Toon.{Constants, EncodeError, Utils}
  alias Toon.Encode.{Objects, Options, Primitives, Strings}

  @doc """
  Encodes Elixir data to TOON format string.

  ## Options

    * `:indent` - Number of spaces for indentation (default: 2)
    * `:delimiter` - Delimiter for array values: "," | "\\t" | "|" (default: ",")
    * `:length_marker` - Prefix for array length marker (default: nil)

  ## Examples

      iex> Toon.Encode.encode(%{"name" => "Alice", "age" => 30})
      {:ok, "age: 30\\nname: Alice"}

      iex> Toon.Encode.encode(%{"tags" => ["elixir", "toon"]})
      {:ok, "tags[2]: elixir,toon"}

      iex> Toon.Encode.encode(nil)
      {:ok, "null"}

      iex> Toon.Encode.encode(%{"name" => "Alice"}, indent: 4)
      {:ok, "name: Alice"}
  """
  @spec encode(Toon.Types.encodable(), keyword()) ::
          {:ok, String.t()} | {:error, EncodeError.t()}
  def encode(data, opts \\ []) do
    start_time = System.monotonic_time()
    metadata = %{data_type: data_type(data)}

    :telemetry.execute([:toon, :encode, :start], %{system_time: System.system_time()}, metadata)

    result =
      with {:ok, validated_opts} <- Options.validate(opts),
           {:ok, normalized} <- normalize(data) do
        try do
          encoded = do_encode(normalized, 0, validated_opts)
          {:ok, IO.iodata_to_binary(encoded)}
        rescue
          e in EncodeError -> {:error, e}
          e -> {:error, EncodeError.exception(message: Exception.message(e), value: data)}
        end
      else
        {:error, error} ->
          {:error,
           EncodeError.exception(
             message: "Invalid options: #{Exception.message(error)}",
             reason: error
           )}
      end

    duration = System.monotonic_time() - start_time

    case result do
      {:ok, encoded} ->
        :telemetry.execute(
          [:toon, :encode, :stop],
          %{duration: duration, size: byte_size(encoded)},
          metadata
        )

      {:error, error} ->
        :telemetry.execute(
          [:toon, :encode, :exception],
          %{duration: duration},
          Map.put(metadata, :error, error)
        )
    end

    result
  end

  defp data_type(data) when is_map(data), do: :map
  defp data_type(data) when is_list(data), do: :list
  defp data_type(nil), do: :null
  defp data_type(data) when is_boolean(data), do: :boolean
  defp data_type(data) when is_number(data), do: :number
  defp data_type(data) when is_binary(data), do: :string
  defp data_type(_), do: :unknown

  @doc """
  Encodes Elixir data to TOON format string, raising on error.

  ## Examples

      iex> Toon.Encode.encode!(%{"name" => "Alice"})
      "name: Alice"

      iex> Toon.Encode.encode!(%{"tags" => ["a", "b"]})
      "tags[2]: a,b"
  """
  @spec encode!(Toon.Types.encodable(), keyword()) :: String.t()
  def encode!(data, opts \\ []) do
    case encode(data, opts) do
      {:ok, result} -> result
      {:error, error} -> raise error
    end
  end

  # Private functions

  @spec normalize(term()) :: {:ok, Toon.Types.encodable()} | {:error, EncodeError.t()}
  defp normalize(data) do
    {:ok, Utils.normalize(data)}
  rescue
    e ->
      {:error,
       EncodeError.exception(message: "Failed to normalize data: #{Exception.message(e)}")}
  end

  @spec do_encode(Toon.Types.encodable(), non_neg_integer(), map()) :: iodata()
  @doc false
  def do_encode(data, depth, opts) do
    cond do
      Utils.primitive?(data) ->
        Primitives.encode(data, opts.delimiter)

      # Check if this is an ordered list (list of {key, value} tuples)
      is_list(data) and tuple_list?(data) ->
        # Convert to map and encode with key order preserved
        map = Map.new(data)
        key_order = Enum.map(data, fn {k, _v} -> k end)
        Objects.encode(map, depth, Map.put(opts, :key_order, key_order))

      Utils.map?(data) ->
        Objects.encode(data, depth, opts)

      Utils.list?(data) ->
        # Root-level arrays per TOON spec Section 5
        encode_root_array(data, depth, opts)

      true ->
        raise EncodeError,
          message: "Cannot encode value of type #{inspect(data.__struct__ || :unknown)}",
          value: data
    end
  end

  # Check if a list is a tuple list (key-value pairs)
  defp tuple_list?([]), do: false
  defp tuple_list?([{k, _v} | _rest]) when is_binary(k), do: true
  defp tuple_list?(_), do: false

  # Encode root-level array per TOON spec Section 5
  defp encode_root_array(data, depth, opts) do
    length_marker = format_length_marker(length(data), opts.length_marker)
    delimiter_marker = if opts.delimiter != ",", do: opts.delimiter, else: ""

    cond do
      # Empty array
      Enum.empty?(data) ->
        length_marker = format_length_marker(0, opts.length_marker)
        ["[", length_marker, "]:"]

      # Inline array (all primitives)
      Utils.all_primitives?(data) ->
        values =
          data
          |> Enum.map(&Primitives.encode(&1, opts.delimiter))
          |> Enum.intersperse(opts.delimiter)

        ["[", length_marker, delimiter_marker, "]: ", values]

      # Tabular array (all maps with same keys)
      Utils.all_maps?(data) and Utils.same_keys?(data) ->
        encode_root_tabular_array(data, length_marker, delimiter_marker, opts)

      # List format (mixed or non-uniform)
      true ->
        encode_root_list_array(data, length_marker, delimiter_marker, depth, opts)
    end
  end

  # Encode root tabular array
  defp encode_root_tabular_array(data, length_marker, delimiter_marker, opts) do
    # Get keys from first object and use provided key order or sort alphabetically
    keys =
      case data do
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

    # Format header
    fields = Enum.map(keys, &Strings.encode_key/1) |> Enum.intersperse(opts.delimiter)

    header = [
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
    rows =
      Enum.map(data, fn obj ->
        values =
          keys
          |> Enum.map(fn k -> Map.get(obj, k) end)
          |> Enum.map(&Primitives.encode(&1, opts.delimiter))
          |> Enum.intersperse(opts.delimiter)

        [opts.indent_string, values]
      end)

    [header | rows]
    |> Enum.map_join("\n", &IO.iodata_to_binary/1)
  end

  # Encode root list array
  defp encode_root_list_array(data, length_marker, delimiter_marker, depth, opts) do
    header = ["[", length_marker, delimiter_marker, "]:"]

    items =
      Enum.flat_map(data, fn item ->
        encode_root_list_item(item, depth, opts)
      end)

    # Don't add extra indentation - items already have their indentation
    [
      IO.iodata_to_binary(header)
      | Enum.map(items, fn line ->
          [opts.indent_string, line]
        end)
    ]
    |> Enum.map_join("\n", &IO.iodata_to_binary/1)
  end

  # Encode a single root list item
  defp encode_root_list_item(item, depth, opts) when is_map(item) do
    entries =
      item
      |> Enum.with_index()
      |> Enum.flat_map(fn {{k, v}, index} ->
        encode_root_list_entry(k, v, index, depth, opts)
      end)

    entries
  end

  defp encode_root_list_item(item, _depth, opts) when is_list(item) do
    # Array item - encode as inline array if all primitives
    cond do
      Enum.empty?(item) ->
        [[Constants.list_item_marker(), Constants.space(), "[0]:"]]

      Utils.all_primitives?(item) ->
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
        # Complex nested array
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

        # Recursively encode nested items
        nested_items =
          Enum.flat_map(item, fn nested_item ->
            nested = encode_root_list_item(nested_item, 0, opts)

            Enum.map(nested, fn line ->
              [opts.indent_string | line]
            end)
          end)

        [header | nested_items]
    end
  end

  defp encode_root_list_item(item, _depth, opts) do
    # Primitive item
    [[Constants.list_item_marker(), Constants.space(), Primitives.encode(item, opts.delimiter)]]
  end

  # Encode a single entry in root list item
  defp encode_root_list_entry(k, v, index, _depth, opts) do
    if Utils.primitive?(v) do
      encoded_key = Strings.encode_key(k)
      needs_marker = index == 0

      line = [
        encoded_key,
        Constants.colon(),
        Constants.space(),
        Primitives.encode(v, opts.delimiter)
      ]

      if needs_marker do
        [[Constants.list_item_marker(), Constants.space() | line]]
      else
        [[opts.indent_string | line]]
      end
    else
      # Complex structures are handled by the array encoder
      []
    end
  end

  # Format length marker
  defp format_length_marker(length, nil), do: Integer.to_string(length)
  defp format_length_marker(length, marker), do: marker <> Integer.to_string(length)
end
