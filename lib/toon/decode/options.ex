defmodule Toon.Decode.Options do
  @moduledoc """
  Validation and normalization of decoding options.
  """

  @options_schema [
    keys: [
      type: {:in, [:strings, :atoms, :atoms!]},
      default: :strings,
      doc: "How to decode map keys: :strings | :atoms | :atoms!"
    ],
    strict: [
      type: :boolean,
      default: true,
      doc: "Enable strict mode validation (indentation, blank lines, etc.)"
    ],
    indent_size: [
      type: :pos_integer,
      default: 2,
      doc: "Expected indentation size in spaces (for strict mode validation)"
    ]
  ]

  @doc """
  Returns the NimbleOptions schema for decoding options.
  """
  @spec schema() :: keyword()
  def schema, do: @options_schema

  @doc """
  Validates and normalizes decoding options.

  ## Examples

      iex> Toon.Decode.Options.validate([])
      {:ok, %{keys: :strings, strict: true, indent_size: 2}}

      iex> Toon.Decode.Options.validate(keys: :atoms)
      {:ok, %{keys: :atoms, strict: true, indent_size: 2}}

      iex> match?({:error, _}, Toon.Decode.Options.validate(keys: :invalid))
      true
  """
  @spec validate(keyword()) :: {:ok, map()} | {:error, NimbleOptions.ValidationError.t()}
  def validate(opts) when is_list(opts) do
    case NimbleOptions.validate(opts, @options_schema) do
      {:ok, validated} -> {:ok, Map.new(validated)}
      {:error, _} = error -> error
    end
  end

  @doc """
  Validates and normalizes decoding options, raising on error.
  """
  @spec validate!(keyword()) :: map()
  def validate!(opts) when is_list(opts) do
    case validate(opts) do
      {:ok, validated} -> validated
      {:error, error} -> raise ArgumentError, Exception.message(error)
    end
  end
end
