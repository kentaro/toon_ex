defmodule Toon.Encode.Strings do
  @moduledoc """
  String encoding utilities for TOON format.

  Handles quote detection, escaping, and key validation.
  """

  alias Toon.Constants

  @doc """
  Encodes a string value, adding quotes if necessary.

  ## Examples

      iex> Toon.Encode.Strings.encode_string("hello")
      "hello"

      iex> Toon.Encode.Strings.encode_string("") |> IO.iodata_to_binary()
      ~s("")

      iex> Toon.Encode.Strings.encode_string("hello world")
      "hello world"

      iex> Toon.Encode.Strings.encode_string("line1\\nline2") |> IO.iodata_to_binary()
      ~s("line1\\\\nline2")
  """
  @spec encode_string(String.t(), String.t()) :: iodata()
  def encode_string(string, delimiter \\ ",") when is_binary(string) do
    if safe_unquoted?(string, delimiter) do
      string
    else
      [Constants.double_quote(), escape_string(string), Constants.double_quote()]
    end
  end

  @doc """
  Encodes a key, adding quotes if necessary.

  Keys have stricter requirements than values:
  - Must match /^[A-Z_][\\w.]*$/i (alphanumeric, underscore, dot)
  - Numbers-only keys must be quoted
  - Keys with special characters must be quoted

  ## Examples

      iex> Toon.Encode.Strings.encode_key("name")
      "name"

      iex> Toon.Encode.Strings.encode_key("user_name")
      "user_name"

      iex> Toon.Encode.Strings.encode_key("user.name")
      "user.name"

      iex> Toon.Encode.Strings.encode_key("user name") |> IO.iodata_to_binary()
      ~s("user name")

      iex> Toon.Encode.Strings.encode_key("123") |> IO.iodata_to_binary()
      ~s("123")
  """
  @spec encode_key(String.t()) :: String.t() | [String.t(), ...]
  def encode_key(key) when is_binary(key) do
    if safe_key?(key) do
      key
    else
      [Constants.double_quote(), escape_string(key), Constants.double_quote()]
    end
  end

  @doc """
  Checks if a string can be used unquoted as a value.

  A string is safe unquoted if:
  - It's not empty
  - It doesn't have leading or trailing spaces
  - It's not a literal (true, false, null)
  - It doesn't look like a number
  - It doesn't contain structure characters or delimiters
  - It doesn't contain control characters
  - It doesn't start with a hyphen

  ## Examples

      iex> Toon.Encode.Strings.safe_unquoted?("hello", ",")
      true

      iex> Toon.Encode.Strings.safe_unquoted?("", ",")
      false

      iex> Toon.Encode.Strings.safe_unquoted?(" hello", ",")
      false

      iex> Toon.Encode.Strings.safe_unquoted?("true", ",")
      false

      iex> Toon.Encode.Strings.safe_unquoted?("42", ",")
      false
  """
  @spec safe_unquoted?(String.t(), String.t()) :: boolean()
  def safe_unquoted?(string, delimiter) when is_binary(string) do
    not (string == "" or needs_quoting_basic?(string) or
           needs_quoting_delimiter?(string, delimiter))
  end

  # Check basic quoting requirements (leading/trailing spaces, literals, numbers, structure)
  defp needs_quoting_basic?(string) do
    has_leading_or_trailing_space?(string) or
      literal?(string) or
      looks_like_number?(string) or
      contains_structure_chars?(string) or
      contains_control_chars?(string) or
      starts_with_hyphen?(string)
  end

  # Check delimiter-specific quoting requirements
  defp needs_quoting_delimiter?(string, delimiter) do
    contains_delimiter?(string, delimiter)
  end

  @doc """
  Checks if a string can be used as an unquoted key.

  A key is safe if it matches /^[A-Z_][\\w.]*$/i

  ## Examples

      iex> Toon.Encode.Strings.safe_key?("name")
      true

      iex> Toon.Encode.Strings.safe_key?("user_name")
      true

      iex> Toon.Encode.Strings.safe_key?("User123")
      true

      iex> Toon.Encode.Strings.safe_key?("user.name")
      true

      iex> Toon.Encode.Strings.safe_key?("user-name")
      false

      iex> Toon.Encode.Strings.safe_key?("123")
      false
  """
  @spec safe_key?(String.t()) :: boolean()
  def safe_key?(key) when is_binary(key) do
    Regex.match?(~r/^[A-Z_][\w.]*$/i, key)
  end

  @doc """
  Escapes special characters in a string.

  ## Examples

      iex> Toon.Encode.Strings.escape_string("hello")
      "hello"

      iex> Toon.Encode.Strings.escape_string("line1\\nline2")
      "line1\\\\nline2"

      iex> result = Toon.Encode.Strings.escape_string(~s(say "hello"))
      iex> String.contains?(result, ~s(\\"))
      true
  """
  @spec escape_string(String.t()) :: String.t()
  def escape_string(string) when is_binary(string) do
    string
    |> String.replace("\\", "\\\\")
    |> String.replace("\"", "\\\"")
    |> String.replace("\n", "\\n")
    |> String.replace("\r", "\\r")
    |> String.replace("\t", "\\t")
  end

  # Private helpers

  defp has_leading_or_trailing_space?(string) do
    String.starts_with?(string, " ") or String.ends_with?(string, " ")
  end

  defp literal?(string) do
    string in [Constants.true_literal(), Constants.false_literal(), Constants.null_literal()]
  end

  defp looks_like_number?(string) do
    case Float.parse(string) do
      {_, ""} -> true
      _ -> false
    end
  end

  defp contains_structure_chars?(string) do
    Enum.any?(Constants.structure_chars(), &String.contains?(string, &1))
  end

  defp contains_delimiter?(string, delimiter) do
    String.contains?(string, delimiter)
  end

  defp contains_control_chars?(string) do
    Enum.any?(Constants.control_chars(), &String.contains?(string, &1))
  end

  defp starts_with_hyphen?(string) do
    String.starts_with?(string, "-")
  end
end
