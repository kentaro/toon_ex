defmodule Toon.DecodeError do
  @moduledoc """
  Exception raised when decoding fails.

  This exception is raised when the decoder encounters an error while
  parsing TOON format strings. It includes detailed information about
  the error location and context.
  """

  defexception [:message, :input, :line, :column, :context, :reason]

  @type t :: %__MODULE__{
          message: String.t(),
          input: String.t() | nil,
          line: pos_integer() | nil,
          column: pos_integer() | nil,
          context: String.t() | nil,
          reason: term()
        }

  @doc """
  Creates a new DecodeError.

  ## Examples

      iex> Toon.DecodeError.exception(message: "Unexpected token", line: 1, column: 5)
      %Toon.DecodeError{
        message: "Unexpected token",
        input: nil,
        line: 1,
        column: 5,
        context: nil,
        reason: nil
      }
  """
  @impl true
  def exception(opts) when is_list(opts) do
    message = Keyword.get(opts, :message, "decode error")
    input = Keyword.get(opts, :input)
    line = Keyword.get(opts, :line)
    column = Keyword.get(opts, :column)
    context = Keyword.get(opts, :context)
    reason = Keyword.get(opts, :reason)

    %__MODULE__{
      message: message,
      input: input,
      line: line,
      column: column,
      context: context,
      reason: reason
    }
  end

  def exception(message) when is_binary(message) do
    %__MODULE__{
      message: message,
      input: nil,
      line: nil,
      column: nil,
      context: nil,
      reason: nil
    }
  end

  @impl true
  def message(%__MODULE__{} = error) do
    parts = [error.message]

    parts =
      if error.line || error.column do
        location =
          case {error.line, error.column} do
            {line, nil} -> " at line #{line}"
            {nil, column} -> " at column #{column}"
            {line, column} -> " at line #{line}, column #{column}"
          end

        [hd(parts) <> location | tl(parts)]
      else
        parts
      end

    parts =
      if error.context do
        parts ++ ["\n\nContext:\n#{error.context}"]
      else
        parts
      end

    Enum.join(parts, "")
  end
end
