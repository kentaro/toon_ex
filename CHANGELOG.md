# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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

[Unreleased]: https://github.com/kentaro/toon_ex/compare/v0.2.0...HEAD
[0.2.0]: https://github.com/kentaro/toon_ex/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/kentaro/toon_ex/releases/tag/v0.1.0
