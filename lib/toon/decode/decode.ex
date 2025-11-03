defmodule Toon.Decode do
  @moduledoc """
  Main decoder for TOON format.

  Parses TOON format strings and converts them to Elixir data structures.
  """

  alias Toon.Decode.{Options, StructuralParser}
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
    # Use structural parser for full TOON support
    case StructuralParser.parse(string, opts) do
      {:ok, result} ->
        result

      {:error, error} ->
        raise error
    end
  end
end
