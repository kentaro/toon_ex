defmodule Toon.Fixtures.UserWithExcept do
  @derive {Toon.Encoder, except: [:password]}
  defstruct [:name, :email, :password]
end

defmodule Toon.Fixtures.CustomDate do
  @moduledoc "Test struct with explicit Toon.Encoder implementation"
  defstruct [:year, :month, :day]
end

defimpl Toon.Encoder, for: Toon.Fixtures.CustomDate do
  def encode(%{year: y, month: m, day: d}, _opts) do
    "#{y}-#{String.pad_leading(to_string(m), 2, "0")}-#{String.pad_leading(to_string(d), 2, "0")}"
  end
end

defmodule Toon.Fixtures.Person do
  @derive Toon.Encoder
  defstruct [:name, :age]
end

defmodule Toon.Fixtures.Company do
  @derive Toon.Encoder
  defstruct [:name, :ceo]
end
