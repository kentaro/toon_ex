defmodule Toon do
  @moduledoc """
  TOON (Token-Oriented Object Notation) encoder and decoder for Elixir.

  TOON is a compact data format optimized for LLM token efficiency, achieving
  30-60% token reduction compared to JSON while maintaining readability.

  ## Features

  - **Token Efficient**: 30-60% fewer tokens than JSON
  - **Human Readable**: Indentation-based structure like YAML
  - **Three Array Formats**: Inline, tabular, and list formats
  - **Type Safe**: Full Dialyzer support with comprehensive typespecs
  - **Protocol Support**: Custom encoding via `Toon.Encoder` protocol

  ## Quick Start

      # Encode Elixir data to TOON
      iex> Toon.encode!(%{"name" => "Alice", "age" => 30})
      "age: 30\\nname: Alice"

      # Decode TOON to Elixir data
      iex> Toon.decode!("name: Alice\\nage: 30")
      %{"name" => "Alice", "age" => 30}

      # Arrays
      iex> Toon.encode!(%{"tags" => ["elixir", "toon"]})
      "tags[2]: elixir,toon"

      # Nested objects
      iex> Toon.encode!(%{"user" => %{"name" => "Bob"}})
      "user:\\n  name: Bob"

  ## Options

  ### Encoding Options

    * `:indent` - Number of spaces for indentation (default: 2)
    * `:delimiter` - Delimiter for array values: "," | "\\t" | "|" (default: ",")
    * `:length_marker` - Prefix for array length marker (default: nil)

  ### Decoding Options

    * `:keys` - How to decode map keys: `:strings` | `:atoms` | `:atoms!` (default: `:strings`)

  ## Custom Encoding

  You can implement the `Toon.Encoder` protocol for your structs:

      defmodule User do
        @derive {Toon.Encoder, only: [:name, :email]}
        defstruct [:id, :name, :email, :password_hash]
      end

      user = %User{id: 1, name: "Alice", email: "alice@example.com"}
      Toon.encode!(user)
      #=> "name: Alice\\nemail: alice@example.com"
  """

  alias Toon.{Decode, DecodeError, Encode, EncodeError}

  @doc """
  Encodes Elixir data to TOON format.

  Returns `{:ok, toon_string}` on success, or `{:error, error}` on failure.

  ## Examples

      iex> Toon.encode(%{"name" => "Alice"})
      {:ok, "name: Alice"}

      iex> Toon.encode(%{"tags" => ["a", "b"]})
      {:ok, "tags[2]: a,b"}

      iex> Toon.encode(%{"user" => %{"name" => "Bob"}})
      {:ok, "user:\\n  name: Bob"}

      iex> Toon.encode(%{"data" => [1, 2, 3]}, delimiter: "\\t")
      {:ok, "data[3\\t]: 1\\t2\\t3"}
  """
  @spec encode(Toon.Types.encodable(), keyword()) ::
          {:ok, String.t()} | {:error, EncodeError.t()}
  defdelegate encode(data, opts \\ []), to: Encode

  @doc """
  Encodes Elixir data to TOON format, raising on error.

  ## Examples

      iex> Toon.encode!(%{"name" => "Alice"})
      "name: Alice"

      iex> Toon.encode!(%{"tags" => ["a", "b"]})
      "tags[2]: a,b"

      iex> Toon.encode!(%{"count" => 42, "active" => true})
      "active: true\\ncount: 42"
  """
  @spec encode!(Toon.Types.encodable(), keyword()) :: String.t()
  defdelegate encode!(data, opts \\ []), to: Encode

  @doc """
  Decodes TOON format string to Elixir data.

  Returns `{:ok, data}` on success, or `{:error, error}` on failure.

  ## Examples

      iex> Toon.decode("name: Alice")
      {:ok, %{"name" => "Alice"}}

      iex> Toon.decode("tags[2]: a,b")
      {:ok, %{"tags" => ["a", "b"]}}
  """
  @spec decode(String.t(), keyword()) ::
          {:ok, Toon.Types.encodable()} | {:error, DecodeError.t()}
  defdelegate decode(string, opts \\ []), to: Decode

  @doc """
  Decodes TOON format string to Elixir data, raising on error.

  ## Examples

      iex> Toon.decode!("name: Alice")
      %{"name" => "Alice"}
  """
  @spec decode!(String.t(), keyword()) :: Toon.Types.encodable()
  defdelegate decode!(string, opts \\ []), to: Decode
end
