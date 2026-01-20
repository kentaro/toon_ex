# Dialyzer warnings to ignore
#
# Protocol fallback implementation that intentionally raises.
# This is expected behavior - the Any implementation raises Protocol.UndefinedError
# when a struct doesn't have an explicit Toon.Encoder implementation.
[
  {"lib/toon/encoder.ex", :no_return}
]
