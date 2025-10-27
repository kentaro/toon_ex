defmodule Toon.EncodeError do
  @moduledoc """
  Exception raised when encoding fails.

  This exception is raised when the encoder encounters an error while
  converting Elixir data structures to TOON format.
  """

  defexception [:message, :value, :reason]

  @type t :: %__MODULE__{
          message: String.t(),
          value: term(),
          reason: term()
        }

  @doc """
  Creates a new EncodeError.

  ## Examples

      iex> Toon.EncodeError.exception(message: "Invalid value", value: :atom)
      %Toon.EncodeError{message: "Invalid value", value: :atom, reason: nil}
  """
  @impl true
  def exception(opts) when is_list(opts) do
    message = Keyword.get(opts, :message, "encode error")
    value = Keyword.get(opts, :value)
    reason = Keyword.get(opts, :reason)

    %__MODULE__{
      message: message,
      value: value,
      reason: reason
    }
  end

  def exception(message) when is_binary(message) do
    %__MODULE__{message: message, value: nil, reason: nil}
  end

  @impl true
  def message(%__MODULE__{message: message, value: nil}) do
    message
  end

  def message(%__MODULE__{message: message, value: value}) do
    "#{message}: #{inspect(value)}"
  end
end
