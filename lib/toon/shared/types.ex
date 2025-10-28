defmodule Toon.Types do
  @moduledoc """
  Type definitions for TOON encoder and decoder.

  This module defines all the types used throughout the TOON library,
  ensuring type safety and better documentation.
  """

  @typedoc """
  A JSON-compatible primitive value.
  """
  @type primitive :: nil | boolean() | number() | String.t()

  @typedoc """
  A JSON-compatible value that can be encoded to TOON format.

  This is a recursive type that includes:
  - Primitives: `nil`, `boolean()`, `number()`, `String.t()`
  - Maps: `%{optional(String.t()) => encodable()}`
  - Lists: `[encodable()]`
  """
  @type encodable ::
          nil
          | boolean()
          | number()
          | String.t()
          | %{optional(String.t()) => encodable()}
          | [encodable()]

  @typedoc """
  Options for encoding TOON format.

  ## Options

    * `:indent` - Number of spaces for indentation (default: 2)
    * `:delimiter` - Delimiter for array values (default: ",")
    * `:length_marker` - Prefix for array length marker (default: nil)

  ## Examples

      Toon.encode!(data, indent: 4)
      Toon.encode!(data, delimiter: "\\t")
      Toon.encode!(data, length_marker: "#")
  """
  @type encode_opts :: [encode_opt()]

  @typedoc """
  A single encoding option.
  """
  @type encode_opt ::
          {:indent, pos_integer()}
          | {:delimiter, delimiter()}
          | {:length_marker, String.t() | nil}

  @typedoc """
  Valid delimiters for array values.

  Can be comma, tab, or pipe character.
  """
  @type delimiter :: binary()

  @typedoc """
  Options for decoding TOON format.

  ## Options

    * `:keys` - How to decode map keys (default: `:strings`)

  ## Examples

      Toon.decode!(toon, keys: :strings)
      Toon.decode!(toon, keys: :atoms)
  """
  @type decode_opts :: [decode_opt()]

  @typedoc """
  A single decoding option.
  """
  @type decode_opt :: {:keys, :strings | :atoms | :atoms!}

  @typedoc """
  Indentation depth level.
  """
  @type depth :: non_neg_integer()

  @typedoc """
  IO data that can be efficiently concatenated.
  """
  @type iodata_result :: iodata()
end
