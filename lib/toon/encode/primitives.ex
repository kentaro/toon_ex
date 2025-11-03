defmodule Toon.Encode.Primitives do
  @moduledoc """
  Encoding of primitive TOON values (nil, boolean, number, string).
  """

  alias Toon.Constants
  alias Toon.Encode.Strings

  @doc """
  Encodes a primitive value to TOON format.

  ## Examples

      iex> Toon.Encode.Primitives.encode(nil, ",")
      "null"

      iex> Toon.Encode.Primitives.encode(true, ",")
      "true"

      iex> Toon.Encode.Primitives.encode(false, ",")
      "false"

      iex> Toon.Encode.Primitives.encode(42, ",")
      "42"

      iex> Toon.Encode.Primitives.encode(3.14, ",")
      "3.14"

      iex> Toon.Encode.Primitives.encode("hello", ",")
      "hello"

      iex> Toon.Encode.Primitives.encode("hello world", ",")
      ~s("hello world")
  """
  @spec encode(term(), String.t()) :: iodata()
  def encode(nil, _delimiter), do: Constants.null_literal()
  def encode(true, _delimiter), do: Constants.true_literal()
  def encode(false, _delimiter), do: Constants.false_literal()

  def encode(value, _delimiter) when is_integer(value) do
    Integer.to_string(value)
  end

  def encode(value, _delimiter) when is_float(value) do
    # Format float without scientific notation
    format_float(value)
  end

  def encode(value, delimiter) when is_binary(value) do
    Strings.encode_string(value, delimiter)
  end

  # Private helpers

  @doc false
  @spec format_float(float()) :: String.t()
  defp format_float(value) when is_float(value) do
    cond do
      # Handle NaN - NaN != NaN is the standard IEEE 754 way to detect NaN
      # credo:disable-for-lines:2
      value != value ->
        Constants.null_literal()

      # Handle infinity - infinity multiplied by 2 equals infinity
      # and is larger than the maximum float
      value > 1.0e308 or value < -1.0e308 ->
        Constants.null_literal()

      # Check if it's a whole number
      trunc(value) == value ->
        # Format as integer without .0 per TOON spec
        Integer.to_string(trunc(value))

      true ->
        # Format with full precision (17 significant digits for IEEE 754 double precision)
        # Use ~.16g to get full precision without scientific notation for most cases
        # But we need to be careful with the format
        str = Float.to_string(value)

        # Check if scientific notation was used
        if String.contains?(str, "e") or String.contains?(str, "E") do
          # Convert from scientific notation
          {float_val, ""} = Float.parse(str)
          # Format with enough precision to preserve the value
          :io_lib.format("~.16f", [float_val])
          |> IO.iodata_to_binary()
          |> String.replace(~r/(\.\d*?)0+$/, "\\1")
          |> String.replace(~r/\.$/, "")
        else
          str
        end
    end
  end
end
