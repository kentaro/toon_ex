defmodule Toon.Encode do
  @moduledoc """
  Main encoder for TOON format.

  This module coordinates the encoding process, dispatching to specialized
  encoders based on the type of value being encoded.
  """

  alias Toon.Encode.{Arrays, Objects, Options, Primitives}
  alias Toon.{EncodeError, Utils}

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
  defp do_encode(data, depth, opts) do
    cond do
      Utils.primitive?(data) ->
        Primitives.encode(data, opts.delimiter)

      Utils.map?(data) ->
        Objects.encode(data, depth, opts)

      Utils.list?(data) ->
        # Top-level arrays need special handling
        # We'll encode them as a pseudo-object with an "items" key
        # or just as primitive array if all primitives
        if Utils.all_primitives?(data) do
          # Encode as inline primitive array without key
          # For top-level, we need a different approach
          data
          |> Enum.map(&Primitives.encode(&1, opts.delimiter))
          |> Enum.intersperse(opts.delimiter)
        else
          # For complex top-level arrays, encode as list items without header
          [_header | items] = Arrays.encode_list("items", data, depth, opts)

          items
          |> Enum.map_join("\n", &IO.iodata_to_binary/1)
        end

      true ->
        raise EncodeError,
          message: "Cannot encode value of type #{inspect(data.__struct__ || :unknown)}",
          value: data
    end
  end
end
