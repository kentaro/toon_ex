defmodule Toon.Decode.Strings do
  @moduledoc """
  String decoding utilities for TOON format.

  Handles unquoting and unescaping of string values.
  """

  @doc """
  Unescapes a string that was escaped during encoding.

  ## Examples

      iex> Toon.Decode.Strings.unescape_string("hello")
      "hello"

      iex> Toon.Decode.Strings.unescape_string("hello\\\\nworld")
      "hello\\nworld"

      iex> Toon.Decode.Strings.unescape_string("say \\\\\"hello\\\\\"")
      "say \\"hello\\""
  """
  @spec unescape_string(String.t()) :: String.t()
  def unescape_string(string) when is_binary(string) do
    string
    |> String.replace("\\n", "\n")
    |> String.replace("\\r", "\r")
    |> String.replace("\\t", "\t")
    |> String.replace("\\\"", "\"")
    |> String.replace("\\\\", "\\")
  end

  @doc """
  Removes surrounding quotes from a quoted string.

  ## Examples

      iex> Toon.Decode.Strings.unquote_string("\\"hello\\"")
      "hello"

      iex> Toon.Decode.Strings.unquote_string("hello")
      "hello"
  """
  @spec unquote_string(String.t()) :: String.t()
  def unquote_string(string) when is_binary(string) do
    if String.starts_with?(string, "\"") and String.ends_with?(string, "\"") do
      string
      |> String.slice(1..-2//1)
      |> unescape_string()
    else
      string
    end
  end
end
