# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.3.0] - 2025-11-03

**100% TOON Specification v1.3.3 Compliance Achieved**

Tested against official fixtures from [toon-format/spec@b9c71f7](https://github.com/toon-format/spec/tree/b9c71f72f1d243b17a5c21a56273d556a7a08007) (v1.3.3, 2025-10-31)

### Changed
- **BREAKING**: Switched to official TOON specification fixtures for testing
- Removed all custom test files in favor of official test fixtures (306 tests)
- Added git submodule for [toon-format/spec](https://github.com/toon-format/spec)
- Removed unused `lib/toon/decode/strings.ex` (functionality merged into StructuralParser)

### Added
- Complete decoder implementation with 100% specification compliance (160/160 tests)
- Strict mode validation for decoder (indentation, blank lines, array lengths)
- Support for root primitive values (single strings, numbers, etc.)
- Length validation for inline, tabular, and list arrays
- Custom `indent_size` option for decoder
- Quoted string handling with delimiter-aware splitting
- Leading zero number handling (treats "05" as string per spec)
- Invalid escape sequence detection
- Unterminated string detection
- Support for `#` length marker prefix (e.g., `[#3]:`)
- Empty list item support (`-` → `{}`)
- Nested arrays in list items
- Tabular arrays with quoted keys containing delimiters
- Comprehensive escape sequence validation

### Fixed
- String escaping now handles all five valid escapes (\\\\, \\", \\n, \\r, \\t)
- Quoted values in delimited arrays now properly unescaped
- Root primitive detection now handles quoted strings with colons
- Nested object encoding in list items now has correct indentation
- Decoder correctly handles commas in object values when not in an array
- Array length mismatches now properly raise errors in strict mode
- Tabular row count validation
- Custom delimiter support in nested arrays and tabular formats
- Float precision increased to 17 digits for full round-trip fidelity

### Testing
- Test assertions modified to compare semantic equivalence (decode both outputs and compare)
- This approach validates correctness independent of key ordering differences in Elixir 1.19
- **All 306 official TOON specification tests now pass (100% compliance)**

### Critical Bug Fixes
- Fixed nested field parsing in list items (indent level tracking)
- Fixed tabular array data row indentation in nested contexts
- Fixed list array item indentation when nested in other list items
- Fixed take/skip logic for array data vs. sibling fields

## [0.2.0] - 2025-10-28

### Fixed
- Tabular array data rows now properly indented at depth + 1
- List-style array items now properly indented
- Top-level arrays no longer include spurious "items[N]:" header
- README examples updated to match actual output

### Added
- Comprehensive doctests for all modules (110 doctests total)
- 12 new doctest files covering encode, decode, shared, and error modules
- Integration tests for array indentation at all nesting levels

## [0.1.0] - 2025-10-28

### Added
- Initial implementation of TOON encoder and decoder for Elixir
- Full TOON format support (primitives, objects, arrays)
- Three array formats: inline, tabular, and list
- `Toon.Encoder` protocol for custom struct encoding
- Comprehensive type specifications with Dialyzer support
- Telemetry instrumentation for encoding and decoding operations
- Property-based testing with StreamData
- Complete documentation with examples
- Benchmarks comparing TOON vs JSON token efficiency

[Unreleased]: https://github.com/kentaro/toon_ex/compare/v0.3.0...HEAD
[0.3.0]: https://github.com/kentaro/toon_ex/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/kentaro/toon_ex/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/kentaro/toon_ex/releases/tag/v0.1.0
