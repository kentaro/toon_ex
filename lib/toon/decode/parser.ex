defmodule Toon.Decode.Parser do
  @moduledoc """
  NimbleParsec-based parser for TOON format.

  This module defines the grammar for parsing TOON format strings.
  """

  import NimbleParsec

  # Basic tokens
  @colon string(":")
  @space string(" ")
  @delimiter choice([string(","), string("\t"), string("|")])

  # Quoted string: "..."
  quoted_string =
    ignore(string("\""))
    |> repeat(
      choice([
        string("\\\"") |> replace("\""),
        string("\\\\") |> replace("\\"),
        string("\\n") |> replace("\n"),
        string("\\r") |> replace("\r"),
        string("\\t") |> replace("\t"),
        utf8_string([not: ?", not: ?\\], min: 1)
      ])
    )
    |> ignore(string("\""))
    |> reduce({IO, :iodata_to_binary, []})

  # Unquoted string: alphanumeric and some special chars
  unquoted_string =
    utf8_string([?a..?z, ?A..?Z, ?0..?9, ?_, ?., ?-], min: 1)

  # Key: quoted or unquoted
  key =
    choice([
      quoted_string,
      unquoted_string
    ])
    |> unwrap_and_tag(:key)

  # Null literal
  null_value = string("null") |> replace(nil) |> unwrap_and_tag(:null)

  # Boolean literals
  bool_value =
    choice([
      string("true") |> replace(true),
      string("false") |> replace(false)
    ])
    |> unwrap_and_tag(:bool)

  # Number: integer or float
  number_value =
    optional(ascii_string([?-], 1))
    |> concat(ascii_string([?0..?9], min: 1))
    |> optional(ascii_string([?.], 1) |> concat(ascii_string([?0..?9], min: 1)))
    |> reduce({Enum, :join, [""]})
    |> map({__MODULE__, :parse_number, []})
    |> unwrap_and_tag(:number)

  # String value: quoted or unquoted
  string_value =
    choice([
      quoted_string,
      # Unquoted value (not starting with special chars)
      utf8_string([not: ?:, not: ?,, not: ?\n, not: ?\r], min: 1)
      |> map({String, :trim, []})
    ])
    |> unwrap_and_tag(:string)

  # Primitive value
  primitive_value =
    choice([
      null_value,
      bool_value,
      number_value,
      string_value
    ])

  # Array length marker: [123] or [#123]
  array_length =
    ignore(string("["))
    |> optional(ignore(string("#")))
    |> ascii_string([?0..?9], min: 1)
    |> ignore(string("]"))
    |> map({String, :to_integer, []})
    |> unwrap_and_tag(:array_length)

  # Inline array values: val1,val2,val3 (or tab/pipe separated)
  inline_array_values =
    primitive_value
    |> repeat(ignore(@delimiter) |> concat(primitive_value))
    |> tag(:inline_array)

  # Key-value pair: key: value
  simple_kv =
    key
    |> ignore(@colon)
    |> ignore(@space)
    |> concat(primitive_value)
    |> reduce({__MODULE__, :make_kv, []})

  # Empty array: key[0]:
  empty_array_line =
    key
    |> concat(array_length)
    |> ignore(@colon)
    |> reduce({__MODULE__, :make_empty_array_kv, []})

  # Inline array: key[N]: val1,val2,val3
  inline_array_line =
    key
    |> concat(array_length)
    |> ignore(@colon)
    |> ignore(@space)
    |> concat(inline_array_values)
    |> reduce({__MODULE__, :make_array_kv, []})

  # Line parser (try inline_array_line before empty_array_line)
  line =
    choice([
      inline_array_line,
      empty_array_line,
      simple_kv
    ])

  defparsec(:parse_line, line)

  # Public helper functions

  @doc false
  def parse_number(str) when is_binary(str) do
    if String.contains?(str, ".") do
      String.to_float(str)
    else
      String.to_integer(str)
    end
  end

  @doc false
  def make_kv([{:key, key}, {_type, value}]) do
    {key, value}
  end

  @doc false
  def make_empty_array_kv([{:key, key}, {:array_length, _len}]) do
    {key, []}
  end

  @doc false
  def make_array_kv([{:key, key}, {:array_length, _len}, {:inline_array, values}]) do
    array_values = Enum.map(values, fn {_type, val} -> val end)
    {key, array_values}
  end
end
