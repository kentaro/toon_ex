defmodule Toon.Decode do
  @moduledoc """
  Main decoder for TOON format.

  Parses TOON format strings and converts them to Elixir data structures.
  """

  alias Toon.Decode.{Options, Parser}
  alias Toon.DecodeError

  @doc """
  Decodes a TOON format string to Elixir data.

  ## Options

    * `:keys` - How to decode map keys: `:strings` | `:atoms` | `:atoms!` (default: `:strings`)

  ## Examples

      iex> Toon.Decode.decode("name: Alice")
      {:ok, %{"name" => "Alice"}}

      iex> Toon.Decode.decode("age: 30")
      {:ok, %{"age" => 30}}

      iex> Toon.Decode.decode("tags[2]: a,b")
      {:ok, %{"tags" => ["a", "b"]}}

      iex> Toon.Decode.decode("name: Alice", keys: :atoms)
      {:ok, %{name: "Alice"}}
  """
  @spec decode(String.t(), keyword()) :: {:ok, term()} | {:error, DecodeError.t()}
  def decode(string, opts \\ []) when is_binary(string) do
    start_time = System.monotonic_time()
    metadata = %{input_size: byte_size(string)}

    :telemetry.execute([:toon, :decode, :start], %{system_time: System.system_time()}, metadata)

    result =
      case Options.validate(opts) do
        {:ok, validated_opts} ->
          try do
            decoded = do_decode(string, validated_opts)
            {:ok, decoded}
          rescue
            e in DecodeError ->
              {:error, e}

            e ->
              {:error,
               DecodeError.exception(
                 message: "Decode failed: #{Exception.message(e)}",
                 input: string
               )}
          end

        {:error, error} ->
          {:error,
           DecodeError.exception(
             message: "Invalid options: #{Exception.message(error)}",
             reason: error
           )}
      end

    duration = System.monotonic_time() - start_time

    case result do
      {:ok, _decoded} ->
        :telemetry.execute(
          [:toon, :decode, :stop],
          %{duration: duration},
          metadata
        )

      {:error, error} ->
        :telemetry.execute(
          [:toon, :decode, :exception],
          %{duration: duration},
          Map.put(metadata, :error, error)
        )
    end

    result
  end

  @doc """
  Decodes a TOON format string to Elixir data, raising on error.

  ## Examples

      iex> Toon.Decode.decode!("name: Alice")
      %{"name" => "Alice"}

      iex> Toon.Decode.decode!("count: 42")
      %{"count" => 42}
  """
  @spec decode!(String.t(), keyword()) :: term()
  def decode!(string, opts \\ []) when is_binary(string) do
    case decode(string, opts) do
      {:ok, result} -> result
      {:error, error} -> raise error
    end
  end

  # Private functions

  @spec do_decode(String.t(), map()) :: term()
  defp do_decode(string, opts) do
    lines =
      string
      |> String.split("\n")
      |> Enum.map(&String.trim_trailing/1)
      |> Enum.reject(&(&1 == ""))

    entries =
      Enum.map(lines, fn line ->
        case parse_line(line) do
          {:ok, {key, value}} -> {key, value}
          {:error, reason} -> raise DecodeError, message: "Parse error: #{reason}", input: line
        end
      end)

    # Convert to map with appropriate key type
    case opts.keys do
      :strings ->
        Map.new(entries)

      :atoms ->
        Map.new(entries, fn {k, v} -> {String.to_atom(k), v} end)

      :atoms! ->
        Map.new(entries, fn {k, v} -> {String.to_existing_atom(k), v} end)
    end
  end

  defp parse_line(line) do
    case Parser.parse_line(line) do
      {:ok, [result], "", _, _, _} ->
        {:ok, result}

      {:ok, _, rest, _, _, _} ->
        {:error, "unexpected characters: #{rest}"}

      {:error, reason, _rest, _, _, _} ->
        {:error, reason}
    end
  end
end
