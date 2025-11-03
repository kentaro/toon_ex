defmodule Toon.Encode.Writer do
  @moduledoc """
  Line writer for managing indentation and line assembly in TOON format.

  This module provides an efficient way to build TOON output with proper
  indentation using IO lists for performance.
  """

  alias Toon.Constants

  @type t :: %__MODULE__{
          lines: [iodata()],
          indent_string: String.t()
        }

  defstruct lines: [], indent_string: "  "

  @doc """
  Creates a new writer with the specified indent size.

  ## Examples

      iex> Toon.Encode.Writer.new(2)
      %Toon.Encode.Writer{lines: [], indent_string: "  "}

      iex> Toon.Encode.Writer.new(4)
      %Toon.Encode.Writer{lines: [], indent_string: "    "}
  """
  @spec new(pos_integer()) :: t()
  def new(indent_size \\ 2) when is_integer(indent_size) and indent_size > 0 do
    %__MODULE__{
      lines: [],
      indent_string: String.duplicate(" ", indent_size)
    }
  end

  @doc """
  Adds a line to the writer with the specified indentation depth.

  ## Examples

      iex> writer = Toon.Encode.Writer.new(2)
      iex> writer = Toon.Encode.Writer.push(writer, "name: Alice", 0)
      iex> Toon.Encode.Writer.to_string(writer)
      "name: Alice"

      iex> writer = Toon.Encode.Writer.new(2)
      iex> writer = Toon.Encode.Writer.push(writer, "name: Alice", 1)
      iex> Toon.Encode.Writer.to_string(writer)
      "  name: Alice"
  """
  @spec push(t(), iodata(), non_neg_integer()) :: t()
  def push(%__MODULE__{} = writer, content, depth) when is_integer(depth) and depth >= 0 do
    indented_line = [List.duplicate(writer.indent_string, depth), content]
    %{writer | lines: [indented_line | writer.lines]}
  end

  @doc """
  Adds multiple lines to the writer at once.

  ## Examples

      iex> writer = Toon.Encode.Writer.new(2)
      iex> writer = Toon.Encode.Writer.push_many(writer, ["name: Alice", "age: 30"], 0)
      iex> Toon.Encode.Writer.to_string(writer)
      "name: Alice\\nage: 30"
  """
  @spec push_many(t(), [iodata()], non_neg_integer()) :: t()
  def push_many(%__MODULE__{} = writer, lines, depth)
      when is_list(lines) and is_integer(depth) and depth >= 0 do
    Enum.reduce(lines, writer, fn line, acc -> push(acc, line, depth) end)
  end

  @doc """
  Converts the writer's accumulated lines to a string.

  Lines are joined with newlines and the result is a single string.

  ## Examples

      iex> writer = Toon.Encode.Writer.new(2)
      iex> writer = Toon.Encode.Writer.push(writer, "name: Alice", 0)
      iex> writer = Toon.Encode.Writer.push(writer, "age: 30", 0)
      iex> Toon.Encode.Writer.to_string(writer)
      "name: Alice\\nage: 30"
  """
  @spec to_string(t()) :: String.t()
  def to_string(%__MODULE__{lines: lines}) do
    lines
    |> Enum.reverse()
    |> Enum.intersperse(Constants.newline())
    |> IO.iodata_to_binary()
  end

  @doc """
  Converts the writer's accumulated lines to IO data.

  This is more efficient than `to_string/1` when the result will be
  written to an IO device.

  ## Examples

      iex> writer = Toon.Encode.Writer.new(2)
      iex> writer = Toon.Encode.Writer.push(writer, "name: Alice", 0)
      iex> iodata = Toon.Encode.Writer.to_iodata(writer)
      iex> IO.iodata_to_binary(iodata)
      "name: Alice"
  """
  @spec to_iodata(t()) :: [iodata()]
  def to_iodata(%__MODULE__{lines: lines}) do
    lines
    |> Enum.reverse()
    |> Enum.intersperse(Constants.newline())
  end

  @doc """
  Returns the number of lines in the writer.

  ## Examples

      iex> writer = Toon.Encode.Writer.new(2)
      iex> Toon.Encode.Writer.line_count(writer)
      0

      iex> writer = Toon.Encode.Writer.new(2)
      iex> writer = Toon.Encode.Writer.push(writer, "name: Alice", 0)
      iex> Toon.Encode.Writer.line_count(writer)
      1
  """
  @spec line_count(t()) :: non_neg_integer()
  def line_count(%__MODULE__{lines: lines}), do: length(lines)

  @doc """
  Checks if the writer is empty.

  ## Examples

      iex> writer = Toon.Encode.Writer.new(2)
      iex> Toon.Encode.Writer.empty?(writer)
      true

      iex> writer = Toon.Encode.Writer.new(2)
      iex> writer = Toon.Encode.Writer.push(writer, "name: Alice", 0)
      iex> Toon.Encode.Writer.empty?(writer)
      false
  """
  @spec empty?(t()) :: boolean()
  def empty?(%__MODULE__{lines: []}), do: true
  def empty?(%__MODULE__{}), do: false
end
