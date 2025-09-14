defmodule TerminalEditor.Buffer do
  @moduledoc """
  Text buffer management for the terminal editor.

  Handles file content, modifications, and buffer operations like insert,
  delete, copy, and paste. Optimized for large files with efficient
  line-based operations.
  """

  defstruct [
    :file_path,
    :lines,
    :modified,
    :encoding,
    :line_ending,
    :error,
    :last_save_time,
    :syntax_language,
    :readonly
  ]

  @type t :: %__MODULE__{
          file_path: String.t() | nil,
          lines: [String.t()],
          modified: boolean(),
          encoding: :utf8 | :latin1 | :ascii,
          line_ending: :lf | :crlf | :cr,
          error: String.t() | nil,
          last_save_time: DateTime.t() | nil,
          syntax_language: atom(),
          readonly: boolean()
        }

  @doc """
  Create a new empty buffer.
  """
  def new(opts \\ []) do
    %__MODULE__{
      file_path: Keyword.get(opts, :file_path),
      lines: [""],
      modified: false,
      encoding: :utf8,
      line_ending: :lf,
      error: nil,
      last_save_time: nil,
      syntax_language: :plain,
      readonly: false
    }
  end

  @doc """
  Load buffer from file.
  """
  def from_file(file_path) do
    case File.read(file_path) do
      {:ok, content} ->
        {lines, line_ending} = parse_content(content)
        encoding = detect_encoding(content)

        %__MODULE__{
          file_path: file_path,
          lines: lines,
          modified: false,
          encoding: encoding,
          line_ending: line_ending,
          error: nil,
          last_save_time: file_modification_time(file_path),
          syntax_language: detect_syntax_language(file_path),
          readonly: not File.exists?(file_path) or not file_writable?(file_path)
        }

      {:error, :enoent} ->
        # File doesn't exist, create new buffer with this path
        %__MODULE__{
          file_path: file_path,
          lines: [""],
          modified: true,
          encoding: :utf8,
          line_ending: :lf,
          error: nil,
          last_save_time: nil,
          syntax_language: detect_syntax_language(file_path),
          readonly: false
        }

      {:error, reason} ->
        %__MODULE__{
          file_path: file_path,
          lines: [""],
          modified: false,
          encoding: :utf8,
          line_ending: :lf,
          error: "Failed to load file: #{inspect(reason)}",
          last_save_time: nil,
          syntax_language: :plain,
          readonly: true
        }
    end
  end

  @doc """
  Save buffer to file.
  """
  def save(buffer) do
    case buffer.file_path do
      nil ->
        {:error, "No file path specified"}

      file_path when buffer.readonly ->
        {:error, "Buffer is read-only"}

      file_path ->
        content = serialize_content(buffer.lines, buffer.line_ending)

        case File.write(file_path, content, [:write]) do
          :ok ->
            {:ok,
             %{
               buffer
               | modified: false,
                 last_save_time: DateTime.utc_now(),
                 error: nil
             }}

          {:error, reason} ->
            error_msg = "Failed to save file: #{inspect(reason)}"
            {:error, %{buffer | error: error_msg}}
        end
    end
  end

  @doc """
  Save buffer to a different file path.
  """
  def save_as(buffer, new_file_path) do
    new_buffer = %{
      buffer
      | file_path: new_file_path,
        syntax_language: detect_syntax_language(new_file_path),
        readonly: false
    }

    save(new_buffer)
  end

  @doc """
  Insert text at specified position.
  """
  def insert_text(buffer, row, col, text) when is_binary(text) do
    if row < 0 or row >= length(buffer.lines) do
      {:error, "Row out of bounds"}
    else
      current_line = Enum.at(buffer.lines, row)

      if col < 0 or col > String.length(current_line) do
        {:error, "Column out of bounds"}
      else
        new_line =
          String.slice(current_line, 0, col) <>
            text <> String.slice(current_line, col..-1)

        new_lines = List.replace_at(buffer.lines, row, new_line)

        {:ok, %{buffer | lines: new_lines, modified: true}}
      end
    end
  end

  @doc """
  Insert multiple lines of text.
  """
  def insert_lines(buffer, row, col, text_lines) when is_list(text_lines) do
    case text_lines do
      [] ->
        {:ok, buffer}

      [single_line] ->
        insert_text(buffer, row, col, single_line)

      [first_line | rest_lines] ->
        current_line = Enum.at(buffer.lines, row)

        if col < 0 or col > String.length(current_line) do
          {:error, "Column out of bounds"}
        else
          # Split the current line at insertion point
          before_cursor = String.slice(current_line, 0, col)
          after_cursor = String.slice(current_line, col..-1)

          # Create the new lines
          new_first_line = before_cursor <> first_line
          new_lines = rest_lines ++ [List.last(rest_lines) <> after_cursor]

          # Replace and insert lines
          lines_before = Enum.take(buffer.lines, row)
          lines_after = Enum.drop(buffer.lines, row + 1)

          all_new_lines =
            lines_before ++
              [new_first_line] ++ Enum.drop(new_lines, -1) ++ lines_after

          {:ok, %{buffer | lines: all_new_lines, modified: true}}
        end
    end
  end

  @doc """
  Delete text range.
  """
  def delete_range(buffer, start_row, start_col, end_row, end_col) do
    cond do
      start_row < 0 or start_row >= length(buffer.lines) ->
        {:error, "Start row out of bounds"}

      end_row < 0 or end_row >= length(buffer.lines) ->
        {:error, "End row out of bounds"}

      start_row > end_row ->
        {:error, "Start row must be <= end row"}

      start_row == end_row and start_col > end_col ->
        {:error, "Start column must be <= end column on same row"}

      true ->
        delete_range_impl(buffer, start_row, start_col, end_row, end_col)
    end
  end

  defp delete_range_impl(buffer, start_row, start_col, end_row, end_col) do
    if start_row == end_row do
      # Delete within single line
      current_line = Enum.at(buffer.lines, start_row)
      before_delete = String.slice(current_line, 0, start_col)
      after_delete = String.slice(current_line, end_col..-1)
      new_line = before_delete <> after_delete

      new_lines = List.replace_at(buffer.lines, start_row, new_line)
      {:ok, %{buffer | lines: new_lines, modified: true}}
    else
      # Delete across multiple lines
      start_line = Enum.at(buffer.lines, start_row)
      end_line = Enum.at(buffer.lines, end_row)

      before_delete = String.slice(start_line, 0, start_col)
      after_delete = String.slice(end_line, end_col..-1)
      merged_line = before_delete <> after_delete

      lines_before = Enum.take(buffer.lines, start_row)
      lines_after = Enum.drop(buffer.lines, end_row + 1)

      new_lines = lines_before ++ [merged_line] ++ lines_after
      {:ok, %{buffer | lines: new_lines, modified: true}}
    end
  end

  @doc """
  Delete entire line.
  """
  def delete_line(buffer, row) do
    if row < 0 or row >= length(buffer.lines) do
      {:error, "Row out of bounds"}
    else
      new_lines = List.delete_at(buffer.lines, row)

      # Ensure at least one empty line remains
      final_lines = if new_lines == [], do: [""], else: new_lines

      {:ok, %{buffer | lines: final_lines, modified: true}}
    end
  end

  @doc """
  Get text at specified range.
  """
  def get_text_range(buffer, start_row, start_col, end_row, end_col) do
    cond do
      start_row < 0 or start_row >= length(buffer.lines) ->
        {:error, "Start row out of bounds"}

      end_row < 0 or end_row >= length(buffer.lines) ->
        {:error, "End row out of bounds"}

      start_row == end_row ->
        line = Enum.at(buffer.lines, start_row)
        text = String.slice(line, start_col, end_col - start_col)
        {:ok, text}

      true ->
        lines_range = Enum.slice(buffer.lines, start_row..end_row)

        # Handle first line
        first_line = String.slice(List.first(lines_range), start_col..-1)

        # Handle middle lines (if any)
        middle_lines = Enum.slice(lines_range, 1..-2)

        # Handle last line  
        last_line = String.slice(List.last(lines_range), 0, end_col)

        all_lines = [first_line] ++ middle_lines ++ [last_line]
        text = Enum.join(all_lines, "\n")

        {:ok, text}
    end
  end

  @doc """
  Get entire line.
  """
  def get_line(buffer, row) do
    if row < 0 or row >= length(buffer.lines) do
      {:error, "Row out of bounds"}
    else
      {:ok, Enum.at(buffer.lines, row)}
    end
  end

  @doc """
  Replace line content.
  """
  def replace_line(buffer, row, new_content) do
    if row < 0 or row >= length(buffer.lines) do
      {:error, "Row out of bounds"}
    else
      new_lines = List.replace_at(buffer.lines, row, new_content)
      {:ok, %{buffer | lines: new_lines, modified: true}}
    end
  end

  @doc """
  Search for text in buffer.
  """
  def search(buffer, query, opts \\ []) do
    case_sensitive = Keyword.get(opts, :case_sensitive, false)
    regex = Keyword.get(opts, :regex, false)
    start_from = Keyword.get(opts, :start_from, {0, 0})

    search_impl(buffer, query, case_sensitive, regex, start_from)
  end

  defp search_impl(buffer, query, case_sensitive, regex, {start_row, start_col}) do
    search_query = if case_sensitive, do: query, else: String.downcase(query)

    search_lines =
      buffer.lines
      |> Enum.with_index()
      |> Enum.drop(start_row)

    find_matches(
      search_lines,
      search_query,
      case_sensitive,
      regex,
      start_row,
      start_col
    )
  end

  defp find_matches([], _query, _case_sensitive, _regex, _start_row, _start_col) do
    {:ok, []}
  end

  defp find_matches(
         [{line, line_index} | rest],
         query,
         case_sensitive,
         regex,
         start_row,
         start_col
       ) do
    search_line = if case_sensitive, do: line, else: String.downcase(line)

    line_start_col = if line_index == start_row, do: start_col, else: 0

    matches =
      if regex do
        find_regex_matches(search_line, query, line_index, line_start_col)
      else
        find_string_matches(search_line, query, line_index, line_start_col)
      end

    case find_matches(rest, query, case_sensitive, regex, start_row, 0) do
      {:ok, rest_matches} -> {:ok, matches ++ rest_matches}
      error -> error
    end
  end

  defp find_string_matches(line, query, line_index, start_col) do
    line_segment = String.slice(line, start_col..-1)

    case String.split(line_segment, query, parts: 2) do
      [_single_part] ->
        # No match found
        []

      [before_match | _] ->
        match_col = start_col + String.length(before_match)

        match = %{
          row: line_index,
          col: match_col,
          length: String.length(query),
          text: query
        }

        # Look for additional matches in the same line
        rest_matches =
          find_string_matches(
            line,
            query,
            line_index,
            match_col + String.length(query)
          )

        [match | rest_matches]
    end
  end

  defp find_regex_matches(line, pattern, line_index, start_col) do
    try do
      line_segment = String.slice(line, start_col..-1)

      case Regex.run(~r/#{pattern}/, line_segment, return: :index) do
        nil ->
          []

        [{match_start, match_length}] ->
          actual_col = start_col + match_start
          match_text = String.slice(line, actual_col, match_length)

          match = %{
            row: line_index,
            col: actual_col,
            length: match_length,
            text: match_text
          }

          # Look for additional matches
          rest_matches =
            find_regex_matches(
              line,
              pattern,
              line_index,
              actual_col + match_length
            )

          [match | rest_matches]
      end
    rescue
      _error -> []
    end
  end

  @doc """
  Get buffer statistics.
  """
  def get_stats(buffer) do
    line_count = length(buffer.lines)
    char_count = buffer.lines |> Enum.map(&String.length/1) |> Enum.sum()

    word_count =
      buffer.lines
      |> Enum.flat_map(&String.split(&1, ~r/\s+/))
      |> Enum.reject(&(&1 == ""))
      |> length()

    %{
      lines: line_count,
      characters: char_count,
      words: word_count,
      modified: buffer.modified,
      file_path: buffer.file_path,
      encoding: buffer.encoding,
      readonly: buffer.readonly
    }
  end

  # Private helper functions

  defp parse_content(content) do
    # Detect line ending style
    line_ending =
      cond do
        String.contains?(content, "\r\n") -> :crlf
        String.contains?(content, "\r") -> :cr
        true -> :lf
      end

    # Split into lines
    lines =
      case line_ending do
        :crlf -> String.split(content, "\r\n")
        :cr -> String.split(content, "\r")
        :lf -> String.split(content, "\n")
      end

    # Ensure at least one line
    final_lines = if lines == [], do: [""], else: lines

    {final_lines, line_ending}
  end

  defp serialize_content(lines, line_ending) do
    line_sep =
      case line_ending do
        :crlf -> "\r\n"
        :cr -> "\r"
        :lf -> "\n"
      end

    Enum.join(lines, line_sep)
  end

  defp detect_encoding(content) do
    # Simple encoding detection
    if String.valid?(content) do
      :utf8
    else
      # Could implement more sophisticated detection
      :latin1
    end
  end

  defp file_modification_time(file_path) do
    case File.stat(file_path) do
      {:ok, stat} ->
        stat.mtime
        |> NaiveDateTime.from_erl!()
        |> DateTime.from_naive!("Etc/UTC")

      {:error, _} ->
        nil
    end
  end

  defp detect_syntax_language(nil), do: :plain

  defp detect_syntax_language(file_path) do
    case Path.extname(file_path) do
      ".ex" -> :elixir
      ".exs" -> :elixir
      ".js" -> :javascript
      ".ts" -> :typescript
      ".py" -> :python
      ".rb" -> :ruby
      ".rs" -> :rust
      ".go" -> :go
      ".c" -> :c
      ".h" -> :c
      ".cpp" -> :cpp
      ".java" -> :java
      ".md" -> :markdown
      ".json" -> :json
      ".yaml" -> :yaml
      ".yml" -> :yaml
      ".html" -> :html
      ".css" -> :css
      ".xml" -> :xml
      _ -> :plain
    end
  end

  defp file_writable?(file_path) do
    case File.stat(file_path) do
      {:ok, stat} ->
        # Check if file is writable (simplified)
        not Enum.member?(stat.access, :read_only)

      {:error, _} ->
        # If file doesn't exist, check if directory is writable
        dir = Path.dirname(file_path)
        File.exists?(dir) and File.dir?(dir)
    end
  end
end
