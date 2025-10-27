defmodule Toon.Constants do
  @moduledoc """
  Constants used throughout the TOON encoder and decoder.

  This module defines all the string literals, delimiters, and special
  characters used in the TOON format.
  """

  # List markers
  @list_item_marker "-"
  @list_item_prefix "- "

  # Structure characters
  @colon ":"
  @comma ","
  @space " "
  @pipe "|"
  @tab "\t"
  @newline "\n"

  # Brackets and braces
  @open_bracket "["
  @close_bracket "]"
  @open_brace "{"
  @close_brace "}"
  @open_paren "("
  @close_paren ")"

  # Quotes
  @double_quote "\""
  @backslash "\\"

  # Literals
  @null_literal "null"
  @true_literal "true"
  @false_literal "false"

  # Escape sequences
  @escape_sequences %{
    "\\" => "\\\\",
    "\"" => "\\\"",
    "\n" => "\\n",
    "\r" => "\\r",
    "\t" => "\\t"
  }

  @unescape_sequences %{
    "\\\\" => "\\",
    "\\\"" => "\"",
    "\\n" => "\n",
    "\\r" => "\r",
    "\\t" => "\t"
  }

  # Delimiters
  @delimiters %{
    comma: @comma,
    tab: @tab,
    pipe: @pipe
  }

  @default_delimiter @comma

  # Default options
  @default_indent 2

  # Public API
  def list_item_marker, do: @list_item_marker
  def list_item_prefix, do: @list_item_prefix
  def colon, do: @colon
  def comma, do: @comma
  def space, do: @space
  def pipe, do: @pipe
  def tab, do: @tab
  def newline, do: @newline
  def open_bracket, do: @open_bracket
  def close_bracket, do: @close_bracket
  def open_brace, do: @open_brace
  def close_brace, do: @close_brace
  def open_paren, do: @open_paren
  def close_paren, do: @close_paren
  def double_quote, do: @double_quote
  def backslash, do: @backslash
  def null_literal, do: @null_literal
  def true_literal, do: @true_literal
  def false_literal, do: @false_literal
  def escape_sequences, do: @escape_sequences
  def unescape_sequences, do: @unescape_sequences
  def delimiters, do: @delimiters
  def default_delimiter, do: @default_delimiter
  def default_indent, do: @default_indent

  @doc """
  Returns the list of valid delimiter values.
  """
  @spec valid_delimiters() :: [String.t()]
  def valid_delimiters, do: [@comma, @tab, @pipe]

  @doc """
  Checks if a delimiter is valid.
  """
  @spec valid_delimiter?(String.t()) :: boolean()
  def valid_delimiter?(delimiter) when delimiter in [@comma, @tab, @pipe], do: true
  def valid_delimiter?(_), do: false

  @doc """
  Returns the list of structure characters that require quoting in keys and values.
  """
  @spec structure_chars() :: [String.t()]
  def structure_chars do
    [
      @colon,
      @comma,
      @open_bracket,
      @close_bracket,
      @open_brace,
      @close_brace,
      @open_paren,
      @close_paren,
      @double_quote,
      @backslash
    ]
  end

  @doc """
  Returns the list of control characters that need escaping.
  """
  @spec control_chars() :: [String.t()]
  def control_chars do
    ["\n", "\r", "\t", "\b", "\f"]
  end
end
