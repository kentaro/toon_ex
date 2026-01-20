defprotocol Toon.Encoder do
  @moduledoc """
  Protocol for encoding custom data structures to TOON format.

  This protocol allows you to define how your custom structs should be
  encoded to TOON format, similar to `Jason.Encoder`.

  ## Example

      defmodule User do
        @derive {Toon.Encoder, only: [:name, :email]}
        defstruct [:id, :name, :email, :password_hash]
      end

  Or implement the protocol manually:

      defimpl Toon.Encoder, for: User do
        def encode(user, opts) do
          %{
            "name" => user.name,
            "email" => user.email
          }
          |> Toon.Encode.encode!(opts)
        end
      end
  """

  @fallback_to_any true

  @doc """
  Encodes the given value to TOON format.

  Returns IO data that can be converted to a string.
  """
  @spec encode(t, keyword()) :: iodata() | map()
  def encode(value, opts)
end

defimpl Toon.Encoder, for: Any do
  defmacro __deriving__(module, struct, opts) do
    fields = fields_to_encode(struct, opts)

    quote do
      defimpl Toon.Encoder, for: unquote(module) do
        def encode(struct, _opts) do
          struct
          |> Map.take(unquote(fields))
          |> Map.new(fn {k, v} -> {to_string(k), Toon.Utils.normalize(v)} end)
        end
      end
    end
  end

  def encode(%_{} = struct, _opts) do
    raise Protocol.UndefinedError,
      protocol: @protocol,
      value: struct,
      description: """
      Toon.Encoder protocol must be explicitly implemented for structs.

      You can derive the implementation using:

          @derive {Toon.Encoder, only: [...]}
          defstruct ...

      or:

          @derive Toon.Encoder
          defstruct ...
      """
  end

  def encode(value, _opts) do
    raise Protocol.UndefinedError,
      protocol: @protocol,
      value: value
  end

  defp fields_to_encode(struct, opts) do
    cond do
      only = Keyword.get(opts, :only) ->
        only

      except = Keyword.get(opts, :except) ->
        Map.keys(struct) -- [:__struct__ | except]

      true ->
        Map.keys(struct) -- [:__struct__]
    end
  end
end

defimpl Toon.Encoder, for: Atom do
  def encode(nil, _opts), do: "null"
  def encode(true, _opts), do: "true"
  def encode(false, _opts), do: "false"

  def encode(atom, _opts) do
    Atom.to_string(atom)
  end
end

defimpl Toon.Encoder, for: BitString do
  def encode(binary, opts) when is_binary(binary) do
    Toon.Encode.Strings.encode_string(binary, opts[:delimiter] || ",")
  end
end

defimpl Toon.Encoder, for: Integer do
  def encode(integer, _opts) do
    Integer.to_string(integer)
  end
end

defimpl Toon.Encoder, for: Float do
  def encode(float, _opts) do
    Toon.Encode.Primitives.encode(float, ",")
  end
end

defimpl Toon.Encoder, for: List do
  def encode(list, opts) do
    Toon.Encode.encode!(list, opts)
  end
end

defimpl Toon.Encoder, for: Map do
  def encode(map, opts) do
    # Convert atom keys to strings
    string_map = Map.new(map, fn {k, v} -> {to_string(k), v} end)
    Toon.Encode.encode!(string_map, opts)
  end
end
