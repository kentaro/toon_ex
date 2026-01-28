defmodule Toon.Decode.StructuralParser do
  @moduledoc """
  Structural parser for TOON format that handles indentation-based nesting.

  This parser processes TOON input by analyzing indentation levels and building
  a hierarchical structure from the flat text representation.
  """

  alias Toon.Decode.Parser
  alias Toon.DecodeError

  @type line_info :: %{
          content: String.t(),
          indent: non_neg_integer(),
          line_number: non_neg_integer(),
          original: String.t()
        }

  @doc """
  Parses TOON input string into a structured format.

  Returns the decoded value which can be a map, list, or primitive.
  """
  @spec parse(String.t(), map()) :: {:ok, term()} | {:error, DecodeError.t()}
  def parse(input, opts) when is_binary(input) do
    lines = preprocess_lines(input)

    # Validate indentation in strict mode
    if opts.strict do
      validate_indentation(lines, opts)
    end

    case lines do
      [] ->
        {:ok, %{}}

      _ ->
        result = parse_structure(lines, 0, opts)
        {:ok, result}
    end
  rescue
    e in DecodeError ->
      {:error, e}

    e ->
      {:error,
       DecodeError.exception(
         message: "Parse failed: #{Exception.message(e)}",
         input: input
       )}
  end

  # Preprocess input into line information structures
  defp preprocess_lines(input) do
    input
    |> String.split("\n")
    |> Enum.with_index(1)
    |> Enum.map(fn {line, line_num} ->
      %{
        content: String.trim_leading(line),
        indent: calculate_indent(line),
        line_number: line_num,
        original: line,
        is_blank: String.trim(line) == ""
      }
    end)
    # Filter out blank lines at the end
    |> Enum.reverse()
    |> Enum.drop_while(& &1.is_blank)
    |> Enum.reverse()
  end

  # Calculate indentation level (number of leading spaces)
  defp calculate_indent(line) do
    line
    |> String.to_charlist()
    |> Enum.take_while(&(&1 == ?\s))
    |> length()
  end

  # Validate indentation in strict mode
  defp validate_indentation(lines, opts) do
    Enum.each(lines, fn line ->
      # Skip blank lines
      unless line.is_blank do
        # Check for tab characters in INDENTATION only (not in content after the key/value starts)
        # We need to check the leading whitespace before any content
        # Find where content starts (first non-whitespace character)
        leading_whitespace =
          line.original
          |> String.to_charlist()
          |> Enum.take_while(&(&1 == ?\s or &1 == ?\t))
          |> List.to_string()

        if String.contains?(leading_whitespace, "\t") do
          raise DecodeError,
            message: "Tab characters are not allowed in indentation (strict mode)",
            input: line.original
        end

        # Check if indent is a multiple of indent_size
        if line.indent > 0 and rem(line.indent, opts.indent_size) != 0 do
          raise DecodeError,
            message: "Indentation must be a multiple of #{opts.indent_size} spaces (strict mode)",
            input: line.original
        end
      end
    end)
  end

  # Parse a structure starting from given lines at a specific indent level
  defp parse_structure(lines, base_indent, opts) do
    {root_type, _} = detect_root_type(lines)

    case root_type do
      :root_array ->
        parse_root_array(lines, opts)

      :root_primitive ->
        parse_root_primitive(lines, opts)

      :object ->
        parse_object_lines(lines, base_indent, opts)
    end
  end

  # Detect if the root is an array or object or primitive
  defp detect_root_type([%{content: content} | rest]) do
    cond do
      # Root array header patterns
      String.starts_with?(content, "[") ->
        {:root_array, :inline}

      String.match?(content, ~r/^\[.*\]\{.*\}:/) ->
        {:root_array, :tabular}

      String.match?(content, ~r/^\[.*\]:/) ->
        {:root_array, :list}

      # Single line -> check if it's a primitive or key-value
      rest == [] ->
        # Check if it looks like a key-value pair by pattern matching
        # Match: <key>: <value> or <key>: (empty) where key can include array markers like [N]
        # Pattern: (quoted_key|unquoted_key)(optional_array_marker): (space or end of line)
        # Quoted keys can contain escaped quotes: "(?:[^"\\]|\\.)*"
        # Unquoted keys can include: letters, numbers, _, -, .
        if String.match?(content, ~r/^(?:"(?:[^"\\]|\\.)*"|[\w.-]+)(?:\[[^\]]*\])?:(?:\s|$)/) do
          # It's a key-value pair -> object
          {:object, nil}
        else
          # Not a valid key-value pair -> treat as root primitive
          {:root_primitive, nil}
        end

      true ->
        {:object, nil}
    end
  end

  # Parse root primitive value (single value without key)
  defp parse_root_primitive([%{content: content}], _opts) do
    # For root primitives, we parse directly without parser combinator
    # This handles quoted strings with escapes correctly
    parse_value(content)
  end

  # Parse root-level array
  defp parse_root_array([%{content: header_line} = line_info | rest], opts) do
    case Parser.parse_line(header_line) do
      {:ok, [result], "", _, _, _} ->
        # Handle inline array
        case result do
          {_key, value} when is_list(value) ->
            value

          _ ->
            raise DecodeError, message: "Invalid root array format", input: header_line
        end

      {:error, _reason, _, _, _, _} ->
        # Try parsing as tabular or list format
        parse_complex_root_array(line_info, rest, opts)
    end
  end

  defp parse_complex_root_array(%{content: header}, rest, opts) do
    cond do
      # Inline array with delimiter marker: [3\t]: ... or [3|]: ... or [3]: ...
      String.match?(header, ~r/^\[\d+[^\]]*\]: /) ->
        parse_root_inline_array(header, opts)

      # Tabular array: [N]{fields}:
      String.match?(header, ~r/^\[\d+[^\]]*\]\{[^}]+\}:$/) ->
        parse_tabular_array_data(header, rest, 0, opts)

      # List array: [N]:
      String.match?(header, ~r/^\[\d+[^\]]*\]:$/) ->
        parse_list_array_items(rest, 0, opts)

      true ->
        raise DecodeError, message: "Invalid root array header", input: header
    end
  end

  # Parse root inline array from header line
  defp parse_root_inline_array(header, _opts) do
    # Extract everything after ": "
    case String.split(header, ": ", parts: 2) do
      [array_marker, values_str] ->
        # Extract declared length from [N] or [#N]
        declared_length =
          case Regex.run(~r/\[#?(\d+)/, array_marker) do
            [_, length_str] -> String.to_integer(length_str)
            _ -> nil
          end

        delimiter = extract_delimiter(array_marker)
        values = parse_delimited_values(values_str, delimiter)

        # Validate length if declared
        if declared_length != nil and length(values) != declared_length do
          raise DecodeError,
            message: "Array length mismatch: declared #{declared_length}, got #{length(values)}",
            input: header
        end

        values

      _ ->
        raise DecodeError, message: "Invalid root inline array", input: header
    end
  end

  # Parse object from lines
  defp parse_object_lines(lines, base_indent, opts) do
    {entries, _remaining} = parse_entries(lines, base_indent, opts)

    # Convert to map with appropriate key type
    case opts.keys do
      :strings ->
        Map.new(entries)

      :atoms ->
        Map.new(entries, fn {k, v} -> {String.to_atom(k), v} end)

      :atoms! ->
        Map.new(entries, fn {k, v} -> {String.to_existing_atom(k), v} end)
    end
  end

  # Parse entries at a specific indentation level
  defp parse_entries([], _base_indent, _opts), do: {[], []}

  defp parse_entries([line | rest] = lines, base_indent, opts) do
    cond do
      # Skip blank lines (only at root level or when not strict)
      line.is_blank ->
        # When strict, blank lines in nested content should be rejected by take_nested_lines
        parse_entries(rest, base_indent, opts)

      # Skip lines that are less indented (parent level)
      line.indent < base_indent ->
        {[], lines}

      # Skip lines that are more indented (will be handled by parent)
      line.indent > base_indent ->
        {[], lines}

      # Process line at current level
      true ->
        case parse_entry_line(line, rest, base_indent, opts) do
          {:entry, key, value, remaining} ->
            {entries, final_remaining} = parse_entries(remaining, base_indent, opts)
            {[{key, value} | entries], final_remaining}

          {:skip, remaining} ->
            parse_entries(remaining, base_indent, opts)
        end
    end
  end

  # Parse a single entry line
  defp parse_entry_line(%{content: content} = line_info, rest, base_indent, opts) do
    case Parser.parse_line(content) do
      {:ok, [result], "", _, _, _} ->
        case result do
          {key, value} when is_list(value) ->
            # Check if this is an empty array with nested content (list or tabular format)
            # Pattern like items[3]: with indented lines following
            if value == [] and peek_next_indent(rest) > base_indent do
              # This is a list/tabular array header, not an inline array
              # Fall through to special line handling
              case handle_special_line(line_info, rest, base_indent, opts) do
                {:skip, _} ->
                  # If special line handling doesn't work, treat as empty array
                  {:entry, key, [], rest}

                result ->
                  result
              end
            else
              # Inline array - ALWAYS re-parse to respect leading zeros and other edge cases
              # The Parser module may have already parsed numbers incorrectly
              # Extract array marker from content to get delimiter
              corrected_value =
                case Regex.run(~r/^[\w"]+(\[#?(\d+)[^\]]*\]):/, content) do
                  [_, array_marker, length_str] ->
                    declared_length = String.to_integer(length_str)
                    delimiter = extract_delimiter(array_marker)
                    # Re-parse the values with correct delimiter
                    case String.split(content, ": ", parts: 2) do
                      [_, values_str] ->
                        values = parse_delimited_values(values_str, delimiter)

                        # Validate length
                        if length(values) != declared_length do
                          raise DecodeError,
                            message:
                              "Array length mismatch: declared #{declared_length}, got #{length(values)}",
                            input: content
                        end

                        values

                      _ ->
                        value
                    end

                  _ ->
                    value
                end

              {:entry, key, corrected_value, rest}
            end

          {key, value} when is_map(value) ->
            # Simple value, not nested
            {:entry, key, value, rest}

          {key, value} ->
            # Check if next lines are nested
            case peek_next_indent(rest) do
              indent when indent > base_indent ->
                # Has nested content
                nested_value = parse_nested_value(key, rest, base_indent, opts)
                {remaining_lines, _} = skip_nested_lines(rest, base_indent)
                {:entry, key, nested_value, remaining_lines}

              _ ->
                # Simple primitive value - re-parse the entire value to respect special cases
                # This handles: leading zeros, commas in strings, etc.
                corrected_value =
                  case String.split(content, ": ", parts: 2) do
                    [_, value_str] ->
                      # Re-parse the entire value string
                      parse_value(String.trim(value_str))

                    _ ->
                      value
                  end

                {:entry, key, corrected_value, rest}
            end
        end

      {:ok, [parsed_result], rest_content, _, _, _} when rest_content != "" ->
        # Parser didn't consume the entire line - re-parse the value manually
        # This handles cases like "note: a,b" where the parser stops at the comma
        case parsed_result do
          {key, _partial_value} ->
            # Re-extract the full value from the original content
            case String.split(content, ": ", parts: 2) do
              [_, value_str] ->
                full_value = parse_value(String.trim(value_str))
                {:entry, key, full_value, rest}

              _ ->
                {:skip, rest}
            end

          _ ->
            {:skip, rest}
        end

      {:ok, _, _, _, _, _} ->
        # Unexpected parse result
        {:skip, rest}

      {:error, reason, _, _, _, _} ->
        # Try to handle special cases like array headers
        # If it still fails, raise an error
        case handle_special_line(line_info, rest, base_indent, opts) do
          {:skip, _} ->
            raise DecodeError,
              message: "Failed to parse line: #{reason}",
              input: content

          result ->
            result
        end
    end
  end

  # Handle special line formats (array headers, etc.)
  defp handle_special_line(%{content: content} = line_info, rest, base_indent, opts) do
    cond do
      # Tabular array header: key[N]{fields}: or key[#N]{fields}: (with optional quoted key)
      String.match?(content, ~r/^(?:"[^"]*"|\w+)\[#?\d+.*\]\{[^}]+\}:$/) ->
        {key, array_value} = parse_tabular_array(line_info, rest, base_indent, opts)
        {remaining, _} = skip_nested_lines(rest, base_indent)
        {:entry, key, array_value, remaining}

      # List array header: key[N]: or key[#N]: (with optional quoted key)
      String.match?(content, ~r/^(?:"[^"]*"|\w+)\[#?\d+.*\]:$/) ->
        {key, array_value} = parse_list_array(line_info, rest, base_indent, opts)
        {remaining, _} = skip_nested_lines(rest, base_indent)
        {:entry, key, array_value, remaining}

      # Empty nested object: key:
      String.ends_with?(content, ":") and not String.contains?(content, " ") ->
        key = String.trim_trailing(content, ":")
        key = unquote_key(key)

        case peek_next_indent(rest) do
          indent when indent > base_indent ->
            # Has nested content
            nested_value = parse_nested_object(rest, base_indent, opts)
            {remaining, _} = skip_nested_lines(rest, base_indent)
            {:entry, key, nested_value, remaining}

          _ ->
            # Empty object
            {:entry, key, %{}, rest}
        end

      true ->
        {:skip, rest}
    end
  end

  # Parse nested value (object or array)
  defp parse_nested_value(_key, lines, base_indent, opts) do
    nested_lines = take_nested_lines(lines, base_indent)
    # Use the actual indent of the first nested line, not base_indent + indent_size
    # This allows non-multiple indentation when strict=false
    actual_indent = get_first_content_indent(nested_lines)
    parse_object_lines(nested_lines, actual_indent, opts)
  end

  # Parse nested object
  defp parse_nested_object(lines, base_indent, opts) do
    nested_lines = take_nested_lines(lines, base_indent)
    # Use the actual indent of the first nested line, not base_indent + indent_size
    actual_indent = get_first_content_indent(nested_lines)
    parse_object_lines(nested_lines, actual_indent, opts)
  end

  # Parse tabular array
  defp parse_tabular_array(%{content: header}, rest, base_indent, opts) do
    # Extract key and fields from header (with optional # length marker and quoted key)
    case Regex.run(~r/^((?:"[^"]*"|\w+))(\[#?\d+.*\])\{([^}]+)\}:$/, header) do
      [_, raw_key, array_marker, fields_str] ->
        key = unquote_key(raw_key)
        delimiter = extract_delimiter(array_marker)
        fields = parse_fields(fields_str, delimiter)

        # Get data rows
        data_rows = take_nested_lines(rest, base_indent)
        array_data = parse_tabular_data_rows(data_rows, fields, delimiter, opts)

        {key, array_data}

      nil ->
        raise DecodeError, message: "Invalid tabular array header", input: header
    end
  end

  # Parse tabular array data rows
  defp parse_tabular_data_rows(lines, fields, delimiter, opts) do
    # Filter out blank lines (validate in strict mode)
    non_blank_lines =
      Enum.reject(lines, fn line ->
        if line.is_blank do
          if opts.strict do
            raise DecodeError,
              message: "Blank lines are not allowed inside arrays in strict mode",
              input: line.original
          end

          true
        else
          false
        end
      end)

    Enum.map(non_blank_lines, fn %{content: row_content} ->
      values = parse_delimited_values(row_content, delimiter)

      if length(values) != length(fields) do
        raise DecodeError,
          message: "Row value count mismatch: expected #{length(fields)}, got #{length(values)}",
          input: row_content
      end

      # Build object from fields and values
      entries = Enum.zip(fields, values)

      case opts.keys do
        :strings -> Map.new(entries)
        :atoms -> Map.new(entries, fn {k, v} -> {String.to_atom(k), v} end)
        :atoms! -> Map.new(entries, fn {k, v} -> {String.to_existing_atom(k), v} end)
      end
    end)
  end

  # Parse tabular array data (for root arrays)
  defp parse_tabular_array_data(header, rest, base_indent, opts) do
    case Regex.run(~r/^\[(#?(\d+))([^\]]*)\]\{([^}]+)\}:$/, header) do
      [_, _full_length, length_str, delimiter_marker, fields_str] ->
        declared_length = String.to_integer(length_str)
        delimiter = extract_delimiter("[#{delimiter_marker}]")
        fields = parse_fields(fields_str, delimiter)
        data_rows = take_nested_lines(rest, base_indent)

        # Validate row count
        if length(data_rows) != declared_length do
          raise DecodeError,
            message:
              "Tabular array row count mismatch: declared #{declared_length}, got #{length(data_rows)}",
            input: header
        end

        parse_tabular_data_rows(data_rows, fields, delimiter, opts)

      nil ->
        raise DecodeError, message: "Invalid tabular array header", input: header
    end
  end

  # Parse list array
  defp parse_list_array(%{content: header}, rest, base_indent, opts) do
    case Regex.run(~r/^((?:"[^"]*"|\w+))\[#?(\d+).*\]:$/, header) do
      [_, raw_key, length_str] ->
        declared_length = String.to_integer(length_str)
        key = unquote_key(raw_key)
        items = parse_list_array_items(rest, base_indent, opts)

        # Validate length
        if length(items) != declared_length do
          raise DecodeError,
            message: "Array length mismatch: declared #{declared_length}, got #{length(items)}",
            input: header
        end

        {key, items}

      nil ->
        raise DecodeError, message: "Invalid list array header", input: header
    end
  end

  # Parse list array items
  defp parse_list_array_items(lines, base_indent, opts) do
    list_lines = take_nested_lines(lines, base_indent)
    # Use the actual indent of the first list item, not base_indent + indent_size
    actual_indent = get_first_content_indent(list_lines)
    parse_list_items(list_lines, actual_indent, opts, [])
  end

  # Parse individual list items
  defp parse_list_items([], _expected_indent, _opts, acc), do: Enum.reverse(acc)

  defp parse_list_items([line | rest], expected_indent, opts, acc) do
    cond do
      # Skip blank lines (validate in strict mode if within array content)
      line.is_blank ->
        if opts.strict do
          raise DecodeError,
            message: "Blank lines are not allowed inside arrays in strict mode",
            input: line.original
        else
          parse_list_items(rest, expected_indent, opts, acc)
        end

      # Inline array item (check before general list marker)
      String.match?(line.content, ~r/^\s*- \[.*\]:/) ->
        {item, remaining} = parse_inline_array_item(line, rest, expected_indent, opts)
        parse_list_items(remaining, expected_indent, opts, [item | acc])

      # List item marker (with space "- " or just "-")
      String.starts_with?(String.trim_leading(line.content), "-") ->
        {item, remaining} = parse_list_item(line, rest, expected_indent, opts)
        parse_list_items(remaining, expected_indent, opts, [item | acc])

      true ->
        parse_list_items(rest, expected_indent, opts, acc)
    end
  end

  # Parse a single list item
  defp parse_list_item(%{content: content} = line, rest, expected_indent, opts) do
    # Remove list marker and parse
    trimmed =
      if String.starts_with?(String.trim_leading(content), "- ") do
        String.trim_leading(content) |> String.replace_prefix("- ", "")
      else
        # Just "-" with no space after
        String.trim_leading(content) |> String.replace_prefix("-", "")
      end

    # Check if this is an inline array: - [N]: val1,val2
    cond do
      # Empty list item (just "-" or "- ")
      trimmed == "" or String.trim(trimmed) == "" ->
        {%{}, rest}

      String.match?(trimmed, ~r/^\[.*?\]:/) ->
        # This is an inline array within a list item
        parse_inline_array_from_line(trimmed, rest)

      # Tabular array as first field: key[N]{fields}: (with optional quoted key)
      String.match?(trimmed, ~r/^(?:"[^"]*"|\w+)\[#?\d+.*\]\{[^}]+\}:$/) ->
        parse_list_item_with_array(trimmed, rest, line, expected_indent, opts, :tabular)

      # List array as first field: key[N]: (with optional quoted key)
      String.match?(trimmed, ~r/^(?:"[^"]*"|\w+)\[#?\d+.*\]:$/) ->
        parse_list_item_with_array(trimmed, rest, line, expected_indent, opts, :list)

      true ->
        # Normal list item parsing (handles all cases including key: with nested content)
        parse_list_item_normal(trimmed, rest, line, expected_indent, opts)
    end
  end

  # Normal list item parsing (extracted to helper)
  defp parse_list_item_normal(trimmed, rest, line, expected_indent, opts) do
    case Parser.parse_line(trimmed) do
      {:ok, [result], "", _, _, _} ->
        case result do
          {_key, _value} ->
            # Object item - collect all fields including continuation lines
            continuation_lines = take_item_lines(rest, expected_indent)

            # Determine the base indent for parsing the object
            # If there are continuation lines, use the indent of the continuation lines
            # Otherwise, use the current line's indent
            item_indent =
              if length(continuation_lines) > 0 do
                # Find the minimum indent of continuation lines
                continuation_lines
                |> Enum.map(& &1.indent)
                |> Enum.min()
              else
                # Single field object, use current line's pseudo-indent
                line.indent
              end

            item_lines = [%{line | content: trimmed, indent: item_indent} | continuation_lines]
            object = parse_object_lines(item_lines, item_indent, opts)

            # Remaining is what's left after the continuation lines
            remaining = Enum.drop(rest, length(continuation_lines))
            {object, remaining}

          value ->
            # Primitive item
            {value, rest}
        end

      {:error, _, _, _, _, _} ->
        # Check if this is a key-only line (e.g., "data:") with nested content
        if String.ends_with?(trimmed, ":") and not String.contains?(trimmed, " ") do
          # Check if there are nested lines
          next_indent = peek_next_indent(rest)

          if next_indent > expected_indent do
            # This is an object key with nested content
            key = String.trim_trailing(trimmed, ":")
            key = unquote_key(key)

            # Take ONLY lines at the immediate next indent level (not shallower sibling fields)
            # For "data:" at indent 2, with next line at indent 6:
            # - Take lines at indent >= 6 (the nested content)
            # - Stop at lines at indent 4 (sibling fields like "id: 2")
            first_nested_indent = next_indent
            nested_lines = take_lines_at_level(rest, first_nested_indent)

            nested_value = parse_object_lines(nested_lines, first_nested_indent, opts)

            # Skip only the lines we consumed (at the nested level)
            remaining_after_nested =
              Enum.drop_while(rest, fn line ->
                !line.is_blank and line.indent >= first_nested_indent
              end)

            # Take remaining fields at the same level
            more_fields = take_item_lines(remaining_after_nested, expected_indent)

            if length(more_fields) > 0 do
              # Parse remaining fields and merge
              field_indent = more_fields |> Enum.map(& &1.indent) |> Enum.min()
              remaining_object = parse_object_lines(more_fields, field_indent, opts)

              object =
                case opts.keys do
                  :strings -> Map.put(remaining_object, key, nested_value)
                  :atoms -> Map.put(remaining_object, String.to_atom(key), nested_value)
                  :atoms! -> Map.put(remaining_object, String.to_existing_atom(key), nested_value)
                end

              final_remaining = Enum.drop(remaining_after_nested, length(more_fields))
              {object, final_remaining}
            else
              # Just the single key
              object =
                case opts.keys do
                  :strings -> %{key => nested_value}
                  :atoms -> %{String.to_atom(key) => nested_value}
                  :atoms! -> %{String.to_existing_atom(key) => nested_value}
                end

              {object, remaining_after_nested}
            end
          else
            # No nested content, treat as primitive value
            value = parse_value(trimmed)
            {value, rest}
          end
        else
          # Primitive value without key - parse as standalone value
          value = parse_value(trimmed)
          {value, rest}
        end
    end
  end

  # Parse list item that starts with an array (tabular or list format)
  defp parse_list_item_with_array(trimmed, rest, _line, expected_indent, opts, array_type) do
    # This handles cases like "- users[2]{id,name}:" or "- matrix[2]:"
    # where the array is the first field in an object

    # Extract the key and parse the array
    {key, array_value} =
      case array_type do
        :tabular ->
          # Extract key, fields from header (with optional quoted key)
          case Regex.run(~r/^((?:"[^"]*"|\w+))(\[#?\d+.*\])\{([^}]+)\}:$/, trimmed) do
            [_, raw_key, array_marker, fields_str] ->
              key = unquote_key(raw_key)
              delimiter = extract_delimiter(array_marker)
              fields = parse_fields(fields_str, delimiter)

              # Take the data rows for this array
              array_lines = take_array_data_lines(rest, expected_indent)
              array_data = parse_tabular_data_rows(array_lines, fields, delimiter, opts)

              {key, array_data}

            nil ->
              raise DecodeError, message: "Invalid tabular array in list item", input: trimmed
          end

        :list ->
          # Extract key from header (with optional quoted key)
          case Regex.run(~r/^((?:"[^"]*"|\w+))\[#?(\d+).*\]:$/, trimmed) do
            [_, raw_key, _length_str] ->
              key = unquote_key(raw_key)

              # Take the nested list items for this array
              array_lines = take_array_data_lines(rest, expected_indent)

              nested_indent =
                if length(array_lines) > 0 do
                  array_lines |> Enum.map(& &1.indent) |> Enum.min()
                else
                  expected_indent + 2
                end

              array_items = parse_list_items(array_lines, nested_indent, opts, [])

              {key, array_items}

            nil ->
              raise DecodeError, message: "Invalid list array in list item", input: trimmed
          end
      end

    # Now collect remaining fields for this object (e.g., "status: active")
    # Skip the array data lines we already consumed
    {rest_after_array, _} = skip_array_data_lines(rest, expected_indent)

    # Take remaining fields at the same level as the list item
    remaining_fields = take_item_lines(rest_after_array, expected_indent)

    # Parse remaining fields as an object
    remaining_object =
      if length(remaining_fields) > 0 do
        field_indent =
          remaining_fields
          |> Enum.map(& &1.indent)
          |> Enum.min()

        parse_object_lines(remaining_fields, field_indent, opts)
      else
        case opts.keys do
          :strings -> %{}
          :atoms -> %{}
          :atoms! -> %{}
        end
      end

    # Merge the array field with remaining fields
    object =
      case opts.keys do
        :strings ->
          Map.put(remaining_object, key, array_value)

        :atoms ->
          Map.put(remaining_object, String.to_atom(key), array_value)

        :atoms! ->
          Map.put(remaining_object, String.to_existing_atom(key), array_value)
      end

    # Skip all lines consumed
    {remaining, _} = skip_item_lines(rest, expected_indent)
    {object, remaining}
  end

  # Take lines for array data (until we hit a non-array line at same level or higher)
  defp take_array_data_lines(lines, base_indent) do
    # For tabular arrays: take lines at depth > base_indent that DON'T look like fields
    # For list arrays: take all lines > base_indent (list items and their nested content)

    # First, check if the first non-blank line starts with "-" (list array) or not (tabular)
    first_content = Enum.find(lines, fn line -> !line.is_blank end)

    is_list_array =
      case first_content do
        %{content: content} -> String.starts_with?(String.trim_leading(content), "-")
        nil -> false
      end

    if is_list_array do
      # For list arrays, we need to carefully track list items and their content
      # Find the expected indent of list items (should be base_indent + 2)
      list_item_indent =
        case first_content do
          %{indent: indent} -> indent
          nil -> base_indent + 2
        end

      # Take all list items and their nested content
      # Stop at lines at list_item_indent level that don't start with "-"
      Enum.take_while(lines, fn line ->
        cond do
          line.is_blank ->
            true

          line.indent > list_item_indent ->
            # Nested content of list items
            true

          line.indent == list_item_indent ->
            # At list item level: only continue if it's a list marker
            String.starts_with?(String.trim_leading(line.content), "-")

          true ->
            false
        end
      end)
    else
      # Tabular array: take lines that don't look like fields
      Enum.take_while(lines, fn line ->
        cond do
          line.is_blank ->
            true

          line.indent > base_indent ->
            # Tabular array: take lines that don't look like "key: value"
            not String.match?(line.content, ~r/^[\w"]+\s*:/)

          true ->
            false
        end
      end)
    end
  end

  # Skip array data lines
  defp skip_array_data_lines(lines, base_indent) do
    # Use same logic as take_array_data_lines
    first_content = Enum.find(lines, fn line -> !line.is_blank end)

    is_list_array =
      case first_content do
        %{content: content} -> String.starts_with?(String.trim_leading(content), "-")
        nil -> false
      end

    remaining =
      if is_list_array do
        # Use same logic as take: find list item indent and skip accordingly
        list_item_indent =
          case first_content do
            %{indent: indent} -> indent
            nil -> base_indent + 2
          end

        Enum.drop_while(lines, fn line ->
          cond do
            line.is_blank ->
              true

            line.indent > list_item_indent ->
              true

            line.indent == list_item_indent ->
              String.starts_with?(String.trim_leading(line.content), "-")

            true ->
              false
          end
        end)
      else
        Enum.drop_while(lines, fn line ->
          cond do
            line.is_blank ->
              true

            line.indent > base_indent ->
              not String.match?(line.content, ~r/^[\w"]+\s*:/)

            true ->
              false
          end
        end)
      end

    {remaining, length(lines) - length(remaining)}
  end

  # Parse inline array from a line like "[2]: a,b"
  defp parse_inline_array_from_line(trimmed, rest) do
    # Extract: [N], [N|], [N\t] format
    case Regex.run(~r/^\[([^\]]+)\]:\s*(.*)$/, trimmed) do
      [_, array_marker, values_str] ->
        delimiter = extract_delimiter(array_marker)

        values =
          if values_str == "" do
            []
          else
            parse_delimited_values(values_str, delimiter)
          end

        {values, rest}

      nil ->
        # Malformed, return as string
        {trimmed, rest}
    end
  end

  # Parse inline array item in list
  defp parse_inline_array_item(%{content: content}, rest, _expected_indent, _opts) do
    trimmed = String.trim_leading(content) |> String.replace_prefix("- ", "")

    # Use parse_inline_array_from_line directly since it handles [N]: format
    parse_inline_array_from_line(trimmed, rest)
  end

  # Parse fields from tabular header
  defp parse_fields(fields_str, delimiter) do
    # Split while respecting quoted strings (same logic as parse_delimited_values)
    delimiter_escaped = Regex.escape(delimiter)
    regex = ~r/("(?:[^"\\]|\\.)*"|[^#{delimiter_escaped}]+)/

    Regex.scan(regex, fields_str)
    |> Enum.map(&hd/1)
    |> Enum.map(&String.trim/1)
    |> Enum.map(&unquote_key/1)
  end

  # Extract delimiter from array marker like [2], [2|], [2\t]
  defp extract_delimiter(array_marker) do
    cond do
      String.contains?(array_marker, "|") -> "|"
      String.contains?(array_marker, "\t") -> "\t"
      true -> ","
    end
  end

  # Parse delimited values from row
  defp parse_delimited_values(row_str, delimiter) do
    # Auto-detect delimiter if the declared delimiter doesn't seem to be present
    actual_delimiter =
      if delimiter == "," and String.contains?(row_str, "\t") and
           not String.contains?(row_str, ",") do
        "\t"
      else
        delimiter
      end

    # Split while respecting quoted strings
    # Match either: "quoted string" or unquoted value (anything except delimiter)
    delimiter_escaped = Regex.escape(actual_delimiter)
    regex = ~r/("(?:[^"\\]|\\.)*"|[^#{delimiter_escaped}]+)/

    Regex.scan(regex, row_str)
    |> Enum.map(&hd/1)
    |> Enum.map(&String.trim/1)
    |> Enum.map(&parse_value/1)
  end

  # Parse a single value
  defp parse_value(str) do
    trimmed = String.trim(str)

    cond do
      trimmed == "null" -> nil
      trimmed == "true" -> true
      trimmed == "false" -> false
      String.starts_with?(trimmed, "\"") -> unquote_string(trimmed)
      true -> parse_number_or_string(trimmed)
    end
  end

  # Parse number or return as string
  defp parse_number_or_string(str) do
    # Per TOON spec: numbers with leading zeros (except "0" itself) are treated as strings
    cond do
      # "0" by itself is a valid number
      str == "0" ->
        0

      # "0" followed by digits is a string (leading zeros)
      String.match?(str, ~r/^0\d/) ->
        str

      # Try to parse as number
      true ->
        case Float.parse(str) do
          {num, ""} ->
            if String.contains?(str, ".") do
              num
            else
              String.to_integer(str)
            end

          _ ->
            str
        end
    end
  end

  # Remove quotes from key
  defp unquote_key(key) do
    if String.starts_with?(key, "\"") and String.ends_with?(key, "\"") do
      key
      |> String.slice(1..-2//1)
      |> unescape_string()
    else
      key
    end
  end

  # Remove quotes and unescape string
  defp unquote_string(str) do
    if String.starts_with?(str, "\"") do
      # Check if string ends with an unescaped quote
      # We need to check that the final " is not preceded by an odd number of backslashes
      if properly_quoted?(str) do
        str
        |> String.slice(1..-2//1)
        |> unescape_string()
      else
        raise DecodeError, message: "Unterminated string", input: str
      end
    else
      str
    end
  end

  # Check if a quoted string is properly terminated
  # The string should start and end with " and the ending " should not be escaped
  defp properly_quoted?(str) do
    if String.length(str) < 2 do
      false
    else
      String.starts_with?(str, "\"") and
        String.ends_with?(str, "\"") and
        not escaped_quote_at_end?(str)
    end
  end

  # Check if the closing quote is escaped
  defp escaped_quote_at_end?(str) do
    # Count consecutive backslashes before the final quote
    # If odd number, the quote is escaped; if even, it's not
    str
    # Remove final quote
    |> String.slice(0..-2//1)
    |> String.reverse()
    |> String.to_charlist()
    |> Enum.take_while(&(&1 == ?\\))
    |> length()
    # Odd number means escaped
    |> rem(2) == 1
  end

  # Unescape string
  defp unescape_string(str) do
    # Per TOON spec: only \\, \", \n, \r, \t are valid escape sequences
    # We need to do replacements in the right order to handle \\ correctly
    # First replace \\ to a placeholder, then other escapes, then placeholder back to \
    str
    |> String.replace("\\\\", <<0>>)
    |> String.replace("\\\"", "\"")
    |> String.replace("\\n", "\n")
    |> String.replace("\\r", "\r")
    |> String.replace("\\t", "\t")
    |> then(fn s ->
      # Check for invalid escapes after handling valid ones
      if String.match?(s, ~r/\\/) do
        raise DecodeError, message: "Invalid escape sequence", input: str
      else
        s
      end
    end)
    |> String.replace(<<0>>, "\\")
  end

  # Peek at next line's indent (skip blank lines)
  defp peek_next_indent([]), do: 0
  defp peek_next_indent([%{is_blank: true} | rest]), do: peek_next_indent(rest)
  defp peek_next_indent([%{indent: indent} | _]), do: indent

  # Get the indent of the first non-blank line
  defp get_first_content_indent([]), do: 0
  defp get_first_content_indent([%{is_blank: true} | rest]), do: get_first_content_indent(rest)
  defp get_first_content_indent([%{indent: indent} | _]), do: indent

  # Take lines at or above a specific indent level (for nested content at exact level)
  defp take_lines_at_level(lines, min_indent) do
    Enum.take_while(lines, fn line ->
      line.is_blank or line.indent >= min_indent
    end)
  end

  # Take lines that are more indented than base
  defp take_nested_lines(lines, base_indent) do
    # We need to handle blank lines carefully:
    # - Blank lines BETWEEN nested content should be included
    # - Blank lines AFTER nested content should NOT be included
    # We'll use a helper that tracks whether we're still in nested content
    take_nested_lines_helper(lines, base_indent, false)
  end

  defp take_nested_lines_helper([], _base_indent, _seen_content), do: []

  defp take_nested_lines_helper([line | rest], base_indent, seen_content) do
    cond do
      # Non-blank line that's more indented: include it and continue
      !line.is_blank and line.indent > base_indent ->
        [line | take_nested_lines_helper(rest, base_indent, true)]

      # Non-blank line at base level or less: stop here
      !line.is_blank ->
        []

      # Blank line: only include if the next non-blank line is still nested
      line.is_blank ->
        next_content_indent = peek_next_indent(rest)

        if next_content_indent > base_indent do
          [line | take_nested_lines_helper(rest, base_indent, seen_content)]
        else
          # Next content is at base level or less, so stop here
          []
        end
    end
  end

  # Skip lines that are more indented than base
  defp skip_nested_lines(lines, base_indent) do
    remaining = Enum.drop_while(lines, fn %{indent: indent} -> indent > base_indent end)
    {remaining, length(lines) - length(remaining)}
  end

  # Take lines for a list item (until next item marker at same level)
  defp take_item_lines(lines, base_indent) do
    Enum.take_while(lines, fn line ->
      # Take lines that are MORE indented than base (continuation lines)
      # Stop at next list item marker at the same level
      if line.indent == base_indent do
        not String.starts_with?(String.trim_leading(line.content), "- ")
      else
        line.indent > base_indent
      end
    end)
  end

  # Skip lines for a list item
  defp skip_item_lines(lines, base_indent) do
    remaining =
      Enum.drop_while(lines, fn line ->
        # Skip lines that are MORE indented than base (continuation lines)
        # Stop at next list item marker at the same level
        if line.indent == base_indent do
          not String.starts_with?(String.trim_leading(line.content), "- ")
        else
          line.indent > base_indent
        end
      end)

    {remaining, length(lines) - length(remaining)}
  end
end
