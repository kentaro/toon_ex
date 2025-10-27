defmodule Toon.Encode.Options do
  @moduledoc """
  Validation and normalization of encoding options using NimbleOptions.
  """

  alias Toon.Constants

  @options_schema [
    indent: [
      type: :pos_integer,
      default: 2,
      doc: "Number of spaces for indentation"
    ],
    delimiter: [
      type: :string,
      default: ",",
      doc: "Delimiter for array values (comma, tab, or pipe)"
    ],
    length_marker: [
      type: {:or, [:string, nil]},
      default: nil,
      doc: "Prefix for array length marker (e.g., '#' produces '[#3]')"
    ]
  ]

  @doc """
  Returns the NimbleOptions schema for encoding options.
  """
  @spec schema() :: keyword()
  def schema, do: @options_schema

  @doc """
  Validates and normalizes encoding options.

  ## Examples

      iex> Toon.Encode.Options.validate([])
      {:ok, %{indent: 2, delimiter: ",", length_marker: nil}}

      iex> Toon.Encode.Options.validate(indent: 4, delimiter: "\\t")
      {:ok, %{indent: 4, delimiter: "\\t", length_marker: nil}}

      iex> Toon.Encode.Options.validate(indent: -1)
      {:error, _}

      iex> Toon.Encode.Options.validate(delimiter: "invalid")
      {:error, _}
  """
  @spec validate(keyword()) :: {:ok, map()} | {:error, NimbleOptions.ValidationError.t()}
  def validate(opts) when is_list(opts) do
    case NimbleOptions.validate(opts, @options_schema) do
      {:ok, validated} ->
        validated_map = Map.new(validated)

        # Additional validation for delimiter
        if valid_delimiter?(validated_map.delimiter) do
          {:ok, validated_map}
        else
          {:error,
           %NimbleOptions.ValidationError{
             key: :delimiter,
             value: validated_map.delimiter,
             message:
               "must be one of: ',' (comma), '\\t' (tab), or '|' (pipe), got: #{inspect(validated_map.delimiter)}"
           }}
        end

      {:error, _} = error ->
        error
    end
  end

  @doc """
  Validates and normalizes encoding options, raising on error.

  ## Examples

      iex> Toon.Encode.Options.validate!([])
      %{indent: 2, delimiter: ",", length_marker: nil}

      iex> Toon.Encode.Options.validate!(indent: 4)
      %{indent: 4, delimiter: ",", length_marker: nil}
  """
  @spec validate!(keyword()) :: map()
  def validate!(opts) when is_list(opts) do
    case validate(opts) do
      {:ok, validated} -> validated
      {:error, error} -> raise ArgumentError, Exception.message(error)
    end
  end

  # Private helpers

  defp valid_delimiter?(delimiter) do
    delimiter in Constants.valid_delimiters()
  end
end
