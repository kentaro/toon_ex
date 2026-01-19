defmodule Toon.Fixtures.UserWithExcept do
  @derive {Toon.Encoder, except: [:password]}
  defstruct [:name, :email, :password]
end
