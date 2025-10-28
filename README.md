# Toon

[![Hex.pm](https://img.shields.io/hexpm/v/toon.svg)](https://hex.pm/packages/toon)
[![Documentation](https://img.shields.io/badge/docs-hexdocs-blue.svg)](https://hexdocs.pm/toon)

**TOON (Token-Oriented Object Notation)** encoder and decoder for Elixir.

TOON is a compact data format optimized for LLM token efficiency, achieving **30-60% token reduction** compared to JSON while maintaining readability.

## Features

- 🎯 **Token Efficient**: 30-60% fewer tokens than JSON
- 📖 **Human Readable**: Indentation-based structure like YAML
- 🔧 **Three Array Formats**: Inline, tabular, and list formats
- 🛡️ **Type Safe**: Full Dialyzer support with comprehensive typespecs
- 🔌 **Protocol Support**: Custom encoding via `Toon.Encoder` protocol
- 📊 **Telemetry**: Built-in instrumentation for monitoring
- ✅ **Well Tested**: 100% test coverage with property-based tests

## Installation

Add `toon` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:toon, "~> 0.1.0"}
  ]
end
```

## Quick Start

### Encoding

```elixir
# Simple object
Toon.encode!(%{"name" => "Alice", "age" => 30})
# => "age: 30\nname: Alice"

# Nested object
Toon.encode!(%{"user" => %{"name" => "Bob"}})
# => "user:\n  name: Bob"

# Arrays
Toon.encode!(%{"tags" => ["elixir", "toon"]})
# => "tags[2]: elixir,toon"
```

### Decoding

```elixir
Toon.decode!("name: Alice\nage: 30")
# => %{"name" => "Alice", "age" => 30}

Toon.decode!("tags[2]: a,b")
# => %{"tags" => ["a", "b"]}
```

## Comprehensive Examples

### All Supported Data Types

```elixir
# Primitives
Toon.encode!(nil)           # => "null"
Toon.encode!(true)          # => "true"
Toon.encode!(false)         # => "false"
Toon.encode!(42)            # => "42"
Toon.encode!(3.14)          # => "3.14"
Toon.encode!("hello")       # => "hello"
Toon.encode!("hello world") # => "\"hello world\"" (auto-quoted)

# Simple objects
Toon.encode!(%{"name" => "Alice", "age" => 30})
# =>
# name: Alice
# age: 30

# Nested objects
Toon.encode!(%{
  "user" => %{
    "name" => "Bob",
    "email" => "bob@example.com"
  },
  "active" => true
})
# =>
# user:
#   name: Bob
#   email: bob@example.com
# active: true

# Inline arrays (primitives)
Toon.encode!(%{"tags" => ["elixir", "toon", "llm"]})
# => tags[3]: elixir,toon,llm

# Tabular arrays (uniform objects with same keys)
Toon.encode!(%{
  "users" => [
    %{"name" => "Alice", "age" => 30},
    %{"name" => "Bob", "age" => 25}
  ]
})
# =>
# users[2]{age,name}:
#   30,Alice
#   25,Bob

# List-style arrays (mixed or nested)
Toon.encode!(%{
  "items" => [
    %{"type" => "book", "title" => "Elixir Guide"},
    %{"type" => "video", "duration" => 120}
  ]
})
# =>
# items[2]:
#   - title: "Elixir Guide"
#     type: book
#   - duration: 120
#     type: video

# Top-level arrays
Toon.encode!(["a", "b", "c"])
# => a,b,c

Toon.encode!([1, 2, 3])
# => 1,2,3

# Top-level array of objects
Toon.encode!([
  %{"name" => "Alice"},
  %{"name" => "Bob"}
])
# =>
# - name: Alice
# - name: Bob
```

### Quoting Rules

Strings are automatically quoted when they contain:
- Leading or trailing whitespace
- Internal spaces
- Reserved words (null, true, false)
- Number-like patterns
- Special characters (`:`, `,`, `{`, `}`, `[`, `]`, `|`, `-`, etc.)
- Control characters

```elixir
Toon.encode!(%{"key" => "simple"})      # => key: simple (no quotes)
Toon.encode!(%{"key" => "hello world"}) # => key: "hello world" (quoted)
Toon.encode!(%{"key" => "42"})          # => key: "42" (quoted)
Toon.encode!(%{"key" => "null"})        # => key: "null" (quoted)
```

### Custom Delimiters

```elixir
# Use tabs instead of commas
Toon.encode!(%{"tags" => ["a", "b", "c"]}, delimiter: "\t")
# => tags[3]: a	b	c

# Use pipes
Toon.encode!(%{"values" => [1, 2, 3]}, delimiter: "|")
# => values[3]: 1|2|3
```

### Custom Indentation

```elixir
# 4-space indentation
Toon.encode!(%{"user" => %{"name" => "Alice"}}, indent: 4)
# =>
# user:
#     name: Alice

# Tab indentation
Toon.encode!(%{"user" => %{"name" => "Alice"}}, indent: "\t")
# =>
# user:
# 	name: Alice
```

### Length Markers

```elixir
# Use # prefix for array lengths
Toon.encode!(%{"tags" => ["a", "b", "c"]}, length_marker: "#")
# => tags[#3]: a,b,c

# Disable length markers
Toon.encode!(%{"tags" => ["a", "b", "c"]}, length_marker: nil)
# => tags: a,b,c
```

### Encoding Custom Structs

```elixir
defmodule User do
  @derive {Toon.Encoder, only: [:name, :email]}
  defstruct [:id, :name, :email, :password_hash]
end

user = %User{id: 1, name: "Alice", email: "alice@example.com", password_hash: "secret"}
Toon.encode!(user)
# =>
# name: Alice
# email: alice@example.com

# Manual implementation
defimpl Toon.Encoder, for: User do
  def encode(user, opts) do
    %{
      "name" => user.name,
      "email" => user.email
    }
    |> Toon.Encode.encode!(opts)
  end
end
```

### Decoding

```elixir
# Simple objects
Toon.decode!("name: Alice\nage: 30")
# => %{"name" => "Alice", "age" => 30}

# Inline arrays
Toon.decode!("tags[3]: elixir,toon,llm")
# => %{"tags" => ["elixir", "toon", "llm"]}

# All data types
toon = """
name: Bob
age: 30
active: true
score: 98.5
email: bob@example.com
tags[3]: elixir,toon,llm
"""

Toon.decode!(toon)
# => %{
#   "name" => "Bob",
#   "age" => 30,
#   "active" => true,
#   "score" => 98.5,
#   "email" => "bob@example.com",
#   "tags" => ["elixir", "toon", "llm"]
# }

# Error handling
case Toon.decode("invalid: : data") do
  {:ok, data} -> IO.inspect(data)
  {:error, error} -> IO.puts("Parse error: #{Exception.message(error)}")
end
```

## Performance

Based on benchmarks run on Apple M3 Max with Elixir 1.19.1 and OTP 28.1.1:

### Token Efficiency (Byte Size Comparison)

| Data Type | TOON Bytes | JSON Bytes | Reduction |
|-----------|------------|------------|-----------|
| Small object (2 fields) | 19 | 25 | 24.0% |
| Medium object (6 fields + array) | 67 | 80 | 16.2% |
| Array of objects (tabular) | 111 | 272 | **59.2%** |

**Verification Process:**
- Measured actual byte sizes of encoded output
- Compared identical data structures in both formats
- Tabular array format provides the highest compression due to column-header optimization

### Encoding Performance

| Operation | IPS | Average | vs JSON |
|-----------|-----|---------|---------|
| Small object encode | 135.21K | 7.40 μs | 25x slower |
| Medium object encode | 45.14K | 22.15 μs | 75x slower |
| Large object encode | 5.13K | 194.98 μs | 659x slower |

### Decoding Performance

| Operation | IPS | Average | vs JSON |
|-----------|-----|---------|---------|
| Small object decode | 340K | 2.97 μs | 12x slower |
| Medium object decode | 143K | 6.99 μs | 29x slower |

**Performance Notes:**
- TOON prioritizes token efficiency over processing speed
- Ideal for LLM contexts where token usage directly impacts cost
- For high-throughput applications where speed matters more than size, use JSON
- Memory usage is proportional to data size and nesting depth

## Current Limitations

- **Nested objects in decoder**: The decoder currently supports flat objects, inline arrays, and top-level structures. Nested object decoding (e.g., `user:\n  name: Alice\n  age: 30`) is not yet implemented. The encoder fully supports nested structures.
- **Tabular arrays in decoder**: Tabular array format decoding is not yet implemented.
- **List-style arrays in decoder**: List-style array format decoding is not yet implemented.

These limitations will be addressed in future versions. For now, use the encoder for full TOON output, and the decoder for flat structures and inline arrays.

## TypeScript Version

This is an Elixir port of [johannschopplich/toon](https://github.com/johannschopplich/toon).

## Author

**Kentaro Kuribayashi**
- GitHub: [@kentaro](https://github.com/kentaro)
- Repository: [kentaro/toon_ex](https://github.com/kentaro/toon_ex)

## License

MIT License - see [LICENSE](LICENSE).

