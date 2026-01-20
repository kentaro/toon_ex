defmodule Toon.Encode.Options do
  @moduledoc """
  Validation and normalization of encoding options using NimbleOptions.
  """

  alias Toon.Constants

  @typedoc "Validated encoding options"
  @type validated :: %{
          indent: pos_integer(),
          delimiter: String.t(),
          length_marker: String.t() | nil,
          key_order: term(),
          indent_string: String.t()
        }

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
    ],
    key_order: [
      type: :any,
      default: nil,
      doc: "Key ordering information for preserving map key order"
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
      {:ok, %{indent: 2, delimiter: ",", length_marker: nil, indent_string: "  "}}

      iex> Toon.Encode.Options.validate(indent: 4, delimiter: "\\t")
      {:ok, %{indent: 4, delimiter: "\\t", length_marker: nil, indent_string: "    "}}

      iex> match?({:error, _}, Toon.Encode.Options.validate(indent: -1))
      true

      iex> match?({:error, _}, Toon.Encode.Options.validate(delimiter: "invalid"))
      true
  """
  @spec validate(keyword()) :: {:ok, map()} | {:error, NimbleOptions.ValidationError.t()}
  def validate(opts) when is_list(opts) do
    case NimbleOptions.validate(opts, @options_schema) do
      {:ok, validated} ->
        validated_map = Map.new(validated)

        # Additional validation for delimiter
        if valid_delimiter?(validated_map.delimiter) do
          # Add computed indent_string based on indent value
          validated_with_indent =
            Map.put(validated_map, :indent_string, String.duplicate(" ", validated_map.indent))

          {:ok, validated_with_indent}
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
      %{indent: 2, delimiter: ",", length_marker: nil, indent_string: "  "}

      iex> Toon.Encode.Options.validate!(indent: 4)
      %{indent: 4, delimiter: ",", length_marker: nil, indent_string: "    "}
  """
  @spec validate!(keyword()) :: validated()
  def validate!(opts) when is_list(opts) do
    case validate(opts) do
      {:ok, validated} ->
        # Add computed indent_string based on indent value
        Map.put(validated, :indent_string, String.duplicate(" ", validated.indent))

      {:error, error} ->
        raise ArgumentError, Exception.message(error)
    end
  end

  # Private helpers

  defp valid_delimiter?(delimiter) do
    delimiter in Constants.valid_delimiters()
  end
end
