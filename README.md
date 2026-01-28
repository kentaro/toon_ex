# Toon

[![Hex.pm](https://img.shields.io/hexpm/v/toon.svg)](https://hex.pm/packages/toon)
[![Documentation](https://img.shields.io/badge/docs-hexdocs-blue.svg)](https://hexdocs.pm/toon)
[![Coverage Status](https://coveralls.io/repos/github/kentaro/toon_ex/badge.svg?branch=main)](https://coveralls.io/github/xu-chris/toon_ex?branch=main)

**TOON (Token-Oriented Object Notation)** encoder and decoder for Elixir.

TOON is a compact data format optimized for LLM token efficiency, achieving **30-60% token reduction** compared to JSON while maintaining readability.

## 🎯 Specification Compliance

This implementation is tested against the [official TOON specification v1.3.3](https://github.com/toon-format/spec) (2025-10-31) using the official test fixtures.

**Test Fixtures:** [toon-format/spec@b9c71f7](https://github.com/toon-format/spec/tree/b9c71f72f1d243b17a5c21a56273d556a7a08007)

**Compliance Status:**
- ✅ **100% (306/306 tests passing)**
- ✅ **Decoder: 100% (160/160 tests)**
- ✅ **Encoder: 100% (146/146 tests)**

Tests validate semantic equivalence (both outputs decode to the same data structure), ensuring correctness independent of Elixir 1.19's automatic key sorting.

## Features

- 🎯 **Token Efficient**: 30-60% fewer tokens than JSON
- 📖 **Human Readable**: Indentation-based structure like YAML
- 🔧 **Three Array Formats**: Inline, tabular, and list formats
- ✅ **Spec Compliant**: Tested against official TOON v1.3 specification
- 🛡️ **Type Safe**: Full Dialyzer support with comprehensive typespecs
- 🔌 **Protocol Support**: Custom encoding via `Toon.Encoder` protocol
- 📊 **Telemetry**: Built-in instrumentation for monitoring

## Installation

Add `toon` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:toon, "~> 0.3.0"}
  ]
end
```

## Quick Start

### Encoding

```elixir
# Simple object
Toon.encode!(%{"name" => "Alice", "age" => 30})
# => "age: 30\\nname: Alice"

# Nested object
Toon.encode!(%{"user" => %{"name" => "Bob"}})
# => "user:\\n  name: Bob"

# Arrays
Toon.encode!(%{"tags" => ["elixir", "toon"]})
# => "tags[2]: elixir,toon"
```

### Decoding

```elixir
Toon.decode!("name: Alice\\nage: 30")
# => %{"name" => "Alice", "age" => 30}

Toon.decode!("tags[2]: a,b")
# => %{"tags" => ["a", "b"]}

# With options
Toon.decode!("user:\\n    name: Alice", indent_size: 4)
# => %{"user" => %{"name" => "Alice"}}
```

## Comprehensive Examples

### Primitives

```elixir
Toon.encode!(nil)            # => "null"
Toon.encode!(true)           # => "true"
Toon.encode!(42)             # => "42"
Toon.encode!(3.14)           # => "3.14"
Toon.encode!("hello")        # => "hello"
Toon.encode!("hello world")  # => "\\"hello world\\"" (auto-quoted)
```

### Objects

```elixir
# Simple objects
Toon.encode!(%{"name" => "Alice", "age" => 30})
# =>
# age: 30
# name: Alice

# Nested objects
Toon.encode!(%{
  "user" => %{
    "name" => "Bob",
    "email" => "bob@example.com"
  }
})
# =>
# user:
#   email: bob@example.com
#   name: Bob
```

### Arrays

```elixir
# Inline arrays (primitives)
Toon.encode!(%{"tags" => ["elixir", "toon", "llm"]})
# => "tags[3]: elixir,toon,llm"

# Tabular arrays (uniform objects)
Toon.encode!(%{
  "users" => [
    %{"name" => "Alice", "age" => 30},
    %{"name" => "Bob", "age" => 25}
  ]
})
# => "users[2]{age,name}:\\n  30,Alice\\n  25,Bob"

# List-style arrays (mixed or nested)
Toon.encode!(%{
  "items" => [
    %{"type" => "book", "title" => "Elixir Guide"},
    %{"type" => "video", "duration" => 120}
  ]
})
# => "items[2]:\\n  - duration: 120\\n    type: video\\n  - title: \\"Elixir Guide\\"\\n    type: book"
```

### Encoding Options

```elixir
# Custom delimiters
Toon.encode!(%{"tags" => ["a", "b", "c"]}, delimiter: "\\t")
# => "tags[3\\t]: a\\tb\\tc"

Toon.encode!(%{"values" => [1, 2, 3]}, delimiter: "|")
# => "values[3|]: 1|2|3"

# Length markers
Toon.encode!(%{"tags" => ["a", "b", "c"]}, length_marker: "#")
# => "tags[#3]: a,b,c"

# Custom indentation
Toon.encode!(%{"user" => %{"name" => "Alice"}}, indent: 4)
# => "user:\\n    name: Alice"
```

### Decoding Options

```elixir
# Atom keys
Toon.decode!("name: Alice", keys: :atoms)
# => %{name: "Alice"}

# Custom indent size
Toon.decode!("user:\\n    name: Alice", indent_size: 4)
# => %{"user" => %{"name" => "Alice"}}

# Strict mode (default: true)
Toon.decode!("  name: Alice", strict: false)  # Accepts non-standard indentation
# => %{"name" => "Alice"}
```

## Specification Compliance

This implementation is tested against the [official TOON specification v1.3](https://github.com/toon-format/spec).

### Test Results

```bash
$ mix test
306 tests, 0 failures

All official TOON specification tests passing (100%)
```

### Fully Supported Features

**Decoder (100% compliant):**
- ✅ All primitive types (strings, numbers, booleans, null)
- ✅ Nested objects with arbitrary depth
- ✅ All three array formats (inline, tabular, list)
- ✅ Custom delimiters (comma, tab, pipe)
- ✅ Quoted strings with escapes (\\\\, \\", \\n, \\r, \\t)
- ✅ Leading zero handling ("05" → string, not number)
- ✅ Strict mode validation (indentation, blank lines, array lengths)
- ✅ Root primitives, arrays, and objects
- ✅ Unicode support (emoji, multi-byte characters)

**Encoder (100% compliant):**
- ✅ All primitive types with proper quoting
- ✅ Nested objects with correct indentation
- ✅ All three array formats (inline, tabular, list)
- ✅ Custom delimiters and length markers
- ✅ Escape sequences
- ✅ Number normalization (-0 → 0, proper precision)
- ✅ Root primitives, arrays, and objects
- ✅ Delimiter-aware quoting
- ✅ Complex nested structures (arrays in list items, etc.)

### Testing Approach

Tests use **semantic equivalence** checking: both encoder output and expected output are decoded and compared. This ensures correctness while accommodating Elixir 1.19's automatic map key sorting (outputs may differ in key order but decode to identical data structures).

## Testing

The test suite uses official TOON specification fixtures:

```bash
# Run all tests against official spec fixtures
mix test

# Run only fixture-based tests
mix test test/toon/fixtures_test.exs
```

Test fixtures are loaded from the [toon-format/spec](https://github.com/toon-format/spec) repository via git submodule.

## TOON Specification

This implementation follows [TOON Specification v1.3](https://github.com/toon-format/spec/blob/main/SPEC.md).

## TypeScript Version

This is an Elixir port of the reference implementation: [toon-format/toon](https://github.com/toon-format/toon).

## Contributing

Contributions are welcome! Please ensure all official specification tests pass before submitting PRs.

## Author

**Kentaro Kuribayashi**
- GitHub: [@kentaro](https://github.com/kentaro)
- Repository: [kentaro/toon_ex](https://github.com/kentaro/toon_ex)

## License

MIT License - see [LICENSE](LICENSE).
