defmodule Examples.Editor.NanoClone do
  @moduledoc """
  A nano-like text editor built with Raxol.

  Features:
  - File loading and saving
  - Syntax highlighting for Elixir code
  - Search and replace
  - Multiple buffers
  - Status bar with file info
  - Keyboard shortcuts

  Run with: mix run examples/editor/nano_clone.ex [filename]
  """

  use Raxol.UI, framework: :raw

  alias Raxol.Terminal.{Emulator, Cursor, Colors}
  alias Raxol.UI.Components.{StatusBar, ScrollView}

  defmodule State do
    @moduledoc false
    defstruct [
      :filename,
      :content,
      :cursor_row,
      :cursor_col,
      :viewport_row,
      :viewport_col,
      :mode,
      :status_message,
      :search_term,
      :modified,
      :syntax_highlighting,
      :file_type,
      :clipboard,
      :undo_stack,
      :redo_stack,
      :selection_start,
      :selection_end
    ]

    def new(filename \\ nil) do
      content =
        if filename && File.exists?(filename) do
          File.read!(filename) |> String.split("\n")
        else
          [""]
        end

      %__MODULE__{
        filename: filename,
        content: content,
        cursor_row: 0,
        cursor_col: 0,
        viewport_row: 0,
        viewport_col: 0,
        mode: :normal,
        status_message:
          "Welcome to Raxol Editor - ^X Exit | ^O Save | ^W Search",
        search_term: nil,
        modified: false,
        syntax_highlighting: true,
        file_type: detect_file_type(filename),
        clipboard: nil,
        undo_stack: [],
        redo_stack: [],
        selection_start: nil,
        selection_end: nil
      }
    end

    defp detect_file_type(nil), do: :text

    defp detect_file_type(filename) do
      case Path.extname(filename) do
        ".ex" -> :elixir
        ".exs" -> :elixir
        ".js" -> :javascript
        ".py" -> :python
        ".md" -> :markdown
        _ -> :text
      end
    end
  end

  def start(args \\ []) do
    filename = List.first(args)
    initial_state = State.new(filename)

    Raxol.Runtime.start_link(
      app: __MODULE__,
      initial_state: initial_state
    )
  end

  @impl true
  def init(state) do
    # Set up terminal for editor
    setup_terminal()
    state
  end

  @impl true
  def update(state, {:key, key}) do
    handle_key(state, key)
  end

  def update(state, {:resize, width, height}) do
    %{state | status_message: "Terminal resized to #{width}x#{height}"}
  end

  def update(state, _event), do: state

  @impl true
  def render(state) do
    {width, height} = terminal_size()

    view do
      # Editor content area
      panel style: [height: height - 2] do
        render_editor_content(state, width, height - 2)
      end

      # Status bar
      panel style: [position: :bottom, height: 1, bg: :blue, fg: :white] do
        render_status_bar(state, width)
      end

      # Command/search bar (if active)
      if state.mode in [:search, :command] do
        panel style: [position: :bottom, height: 1, bg: :black, fg: :yellow] do
          render_command_bar(state, width)
        end
      end
    end
  end

  # Key handling

  defp handle_key(state, {:ctrl, ?x}) do
    # Exit
    if state.modified do
      %{
        state
        | mode: :confirm_exit,
          status_message:
            "Unsaved changes! Press ^X again to exit, or ^C to cancel"
      }
    else
      System.halt(0)
    end
  end

  defp handle_key(%{mode: :confirm_exit} = state, {:ctrl, ?x}) do
    System.halt(0)
  end

  defp handle_key(%{mode: :confirm_exit} = state, _) do
    %{state | mode: :normal, status_message: "Exit cancelled"}
  end

  defp handle_key(state, {:ctrl, ?o}) do
    # Save file
    save_file(state)
  end

  defp handle_key(state, {:ctrl, ?w}) do
    # Search
    %{state | mode: :search, search_term: "", status_message: "Search: "}
  end

  defp handle_key(%{mode: :search} = state, {:char, char}) do
    search_term = (state.search_term || "") <> <<char>>
    %{state | search_term: search_term} |> perform_search()
  end

  defp handle_key(%{mode: :search} = state, :enter) do
    %{state | mode: :normal} |> perform_search()
  end

  defp handle_key(%{mode: :search} = state, :escape) do
    %{
      state
      | mode: :normal,
        search_term: nil,
        status_message: "Search cancelled"
    }
  end

  defp handle_key(state, :up) do
    move_cursor(state, :up)
  end

  defp handle_key(state, :down) do
    move_cursor(state, :down)
  end

  defp handle_key(state, :left) do
    move_cursor(state, :left)
  end

  defp handle_key(state, :right) do
    move_cursor(state, :right)
  end

  defp handle_key(state, :home) do
    %{state | cursor_col: 0}
  end

  defp handle_key(state, :end) do
    line = Enum.at(state.content, state.cursor_row, "")
    %{state | cursor_col: String.length(line)}
  end

  defp handle_key(state, :page_up) do
    {_, height} = terminal_size()
    new_row = max(0, state.cursor_row - (height - 2))
    %{state | cursor_row: new_row} |> adjust_viewport()
  end

  defp handle_key(state, :page_down) do
    {_, height} = terminal_size()
    new_row = min(length(state.content) - 1, state.cursor_row + (height - 2))
    %{state | cursor_row: new_row} |> adjust_viewport()
  end

  defp handle_key(state, :backspace) do
    delete_char(state, :backward)
  end

  defp handle_key(state, :delete) do
    delete_char(state, :forward)
  end

  defp handle_key(state, :enter) do
    insert_newline(state)
  end

  defp handle_key(state, {:char, char}) when char >= 32 and char <= 126 do
    insert_char(state, char)
  end

  defp handle_key(state, {:ctrl, ?z}) do
    undo(state)
  end

  defp handle_key(state, {:ctrl, ?y}) do
    redo(state)
  end

  defp handle_key(state, {:ctrl, ?k}) do
    # Cut line
    cut_line(state)
  end

  defp handle_key(state, {:ctrl, ?u}) do
    # Paste
    paste(state)
  end

  defp handle_key(state, _key) do
    state
  end

  # Editor operations

  defp move_cursor(state, :up) when state.cursor_row > 0 do
    new_row = state.cursor_row - 1
    line = Enum.at(state.content, new_row, "")
    new_col = min(state.cursor_col, String.length(line))
    %{state | cursor_row: new_row, cursor_col: new_col} |> adjust_viewport()
  end

  defp move_cursor(state, :down)
       when state.cursor_row < length(state.content) - 1 do
    new_row = state.cursor_row + 1
    line = Enum.at(state.content, new_row, "")
    new_col = min(state.cursor_col, String.length(line))
    %{state | cursor_row: new_row, cursor_col: new_col} |> adjust_viewport()
  end

  defp move_cursor(state, :left) when state.cursor_col > 0 do
    %{state | cursor_col: state.cursor_col - 1} |> adjust_viewport()
  end

  defp move_cursor(state, :right) do
    line = Enum.at(state.content, state.cursor_row, "")

    if state.cursor_col < String.length(line) do
      %{state | cursor_col: state.cursor_col + 1} |> adjust_viewport()
    else
      state
    end
  end

  defp move_cursor(state, _), do: state

  defp insert_char(state, char) do
    save_undo(state)

    line = Enum.at(state.content, state.cursor_row, "")
    {before, after_cursor} = String.split_at(line, state.cursor_col)
    new_line = before <> <<char>> <> after_cursor

    new_content = List.replace_at(state.content, state.cursor_row, new_line)

    %{
      state
      | content: new_content,
        cursor_col: state.cursor_col + 1,
        modified: true,
        redo_stack: []
    }
  end

  defp insert_newline(state) do
    save_undo(state)

    line = Enum.at(state.content, state.cursor_row, "")
    {before, after_cursor} = String.split_at(line, state.cursor_col)

    new_content =
      state.content
      |> List.replace_at(state.cursor_row, before)
      |> List.insert_at(state.cursor_row + 1, after_cursor)

    %{
      state
      | content: new_content,
        cursor_row: state.cursor_row + 1,
        cursor_col: 0,
        modified: true,
        redo_stack: []
    }
    |> adjust_viewport()
  end

  defp delete_char(state, :backward) when state.cursor_col > 0 do
    save_undo(state)

    line = Enum.at(state.content, state.cursor_row, "")
    {before, after_cursor} = String.split_at(line, state.cursor_col)
    new_line = String.slice(before, 0..-2) <> after_cursor

    new_content = List.replace_at(state.content, state.cursor_row, new_line)

    %{
      state
      | content: new_content,
        cursor_col: state.cursor_col - 1,
        modified: true,
        redo_stack: []
    }
  end

  defp delete_char(state, :backward) when state.cursor_row > 0 do
    # Join with previous line
    save_undo(state)

    prev_line = Enum.at(state.content, state.cursor_row - 1, "")
    curr_line = Enum.at(state.content, state.cursor_row, "")
    new_line = prev_line <> curr_line

    new_content =
      state.content
      |> List.replace_at(state.cursor_row - 1, new_line)
      |> List.delete_at(state.cursor_row)

    %{
      state
      | content: new_content,
        cursor_row: state.cursor_row - 1,
        cursor_col: String.length(prev_line),
        modified: true,
        redo_stack: []
    }
    |> adjust_viewport()
  end

  defp delete_char(state, :forward) do
    line = Enum.at(state.content, state.cursor_row, "")

    cond do
      state.cursor_col < String.length(line) ->
        save_undo(state)
        {before, after_cursor} = String.split_at(line, state.cursor_col)
        new_line = before <> String.slice(after_cursor, 1..-1)
        new_content = List.replace_at(state.content, state.cursor_row, new_line)

        %{state | content: new_content, modified: true, redo_stack: []}

      state.cursor_row < length(state.content) - 1 ->
        # Join with next line
        save_undo(state)
        next_line = Enum.at(state.content, state.cursor_row + 1, "")
        new_line = line <> next_line

        new_content =
          state.content
          |> List.replace_at(state.cursor_row, new_line)
          |> List.delete_at(state.cursor_row + 1)

        %{state | content: new_content, modified: true, redo_stack: []}

      true ->
        state
    end
  end

  defp delete_char(state, _), do: state

  defp cut_line(state) do
    save_undo(state)

    line = Enum.at(state.content, state.cursor_row, "")
    new_content = List.replace_at(state.content, state.cursor_row, "")

    %{
      state
      | content: new_content,
        clipboard: line,
        cursor_col: 0,
        modified: true,
        status_message: "Line cut to clipboard"
    }
  end

  defp paste(state) when is_binary(state.clipboard) do
    save_undo(state)

    line = Enum.at(state.content, state.cursor_row, "")
    {before, after_cursor} = String.split_at(line, state.cursor_col)
    new_line = before <> state.clipboard <> after_cursor

    new_content = List.replace_at(state.content, state.cursor_row, new_line)

    %{
      state
      | content: new_content,
        cursor_col: state.cursor_col + String.length(state.clipboard),
        modified: true,
        status_message: "Pasted from clipboard"
    }
  end

  defp paste(state), do: %{state | status_message: "Clipboard is empty"}

  defp save_undo(state) do
    undo_entry = %{
      content: state.content,
      cursor_row: state.cursor_row,
      cursor_col: state.cursor_col
    }

    %{state | undo_stack: [undo_entry | Enum.take(state.undo_stack, 99)]}
  end

  defp undo(state) when length(state.undo_stack) > 0 do
    [previous | rest] = state.undo_stack

    redo_entry = %{
      content: state.content,
      cursor_row: state.cursor_row,
      cursor_col: state.cursor_col
    }

    %{
      state
      | content: previous.content,
        cursor_row: previous.cursor_row,
        cursor_col: previous.cursor_col,
        undo_stack: rest,
        redo_stack: [redo_entry | state.redo_stack],
        status_message: "Undone"
    }
  end

  defp undo(state), do: %{state | status_message: "Nothing to undo"}

  defp redo(state) when length(state.redo_stack) > 0 do
    [next | rest] = state.redo_stack

    undo_entry = %{
      content: state.content,
      cursor_row: state.cursor_row,
      cursor_col: state.cursor_col
    }

    %{
      state
      | content: next.content,
        cursor_row: next.cursor_row,
        cursor_col: next.cursor_col,
        redo_stack: rest,
        undo_stack: [undo_entry | state.undo_stack],
        status_message: "Redone"
    }
  end

  defp redo(state), do: %{state | status_message: "Nothing to redo"}

  defp save_file(%{filename: nil} = state) do
    %{state | mode: :save_as, status_message: "Save as: "}
  end

  defp save_file(state) do
    content = Enum.join(state.content, "\n")

    case File.write(state.filename, content) do
      :ok ->
        %{
          state
          | modified: false,
            status_message:
              "Saved #{state.filename} (#{String.length(content)} bytes)"
        }

      {:error, reason} ->
        %{state | status_message: "Error saving: #{inspect(reason)}"}
    end
  end

  defp perform_search(state)
       when is_binary(state.search_term) and state.search_term != "" do
    # Simple search - find next occurrence
    found =
      Enum.with_index(state.content)
      |> Enum.drop(state.cursor_row)
      |> Enum.find_value(fn {line, row_idx} ->
        case :binary.match(line, state.search_term) do
          {col_idx, _} -> {row_idx, col_idx}
          :nomatch -> nil
        end
      end)

    case found do
      {row, col} ->
        %{
          state
          | cursor_row: row,
            cursor_col: col,
            status_message: "Found '#{state.search_term}' at line #{row + 1}"
        }
        |> adjust_viewport()

      nil ->
        %{state | status_message: "'#{state.search_term}' not found"}
    end
  end

  defp perform_search(state), do: state

  defp adjust_viewport(state) do
    {width, height} = terminal_size()
    viewport_height = height - 2

    # Adjust vertical viewport
    state =
      cond do
        state.cursor_row < state.viewport_row ->
          %{state | viewport_row: state.cursor_row}

        state.cursor_row >= state.viewport_row + viewport_height ->
          %{state | viewport_row: state.cursor_row - viewport_height + 1}

        true ->
          state
      end

    # Adjust horizontal viewport
    cond do
      state.cursor_col < state.viewport_col ->
        %{state | viewport_col: state.cursor_col}

      state.cursor_col >= state.viewport_col + width ->
        %{state | viewport_col: state.cursor_col - width + 1}

      true ->
        state
    end
  end

  # Rendering

  defp render_editor_content(state, width, height) do
    visible_lines =
      state.content
      |> Enum.drop(state.viewport_row)
      |> Enum.take(height)
      |> Enum.with_index(state.viewport_row)

    Enum.map(visible_lines, fn {line, row_idx} ->
      render_line(state, line, row_idx, width)
    end)
  end

  defp render_line(state, line, row_idx, width) do
    # Line numbers
    line_num = String.pad_leading("#{row_idx + 1}", 4)

    # Get visible portion of line
    visible_text =
      line
      |> String.slice(state.viewport_col, width - 5)
      |> String.pad_trailing(width - 5)

    # Apply syntax highlighting if enabled
    highlighted =
      if state.syntax_highlighting do
        apply_syntax_highlighting(visible_text, state.file_type)
      else
        visible_text
      end

    # Render with cursor
    if row_idx == state.cursor_row do
      cursor_col = state.cursor_col - state.viewport_col + 5
      render_with_cursor(line_num <> " " <> highlighted, cursor_col)
    else
      span(style: [fg: :dark_gray]) do
        line_num
      end <> " " <> highlighted
    end
  end

  defp render_with_cursor(text, cursor_pos) do
    {before, at_and_after_cursor} = String.split_at(text, cursor_pos)
    {at_cursor, after_cursor} = String.split_at(at_and_after_cursor, 1)

    before <>
      span(style: [bg: :white, fg: :black]) do
        if at_cursor == "", do: " ", else: at_cursor
      end <>
      after_cursor
  end

  defp apply_syntax_highlighting(text, :elixir) do
    # Simple Elixir syntax highlighting
    text
    |> String.replace(
      ~r/\b(def|defp|defmodule|do|end|if|else|case|when|fn)\b/,
      fn keyword -> "\e[34m#{keyword}\e[0m" end
    )
    |> String.replace(
      ~r/\b(true|false|nil)\b/,
      fn literal -> "\e[33m#{literal}\e[0m" end
    )
    |> String.replace(
      ~r/"[^"]*"/,
      fn string -> "\e[32m#{string}\e[0m" end
    )
    |> String.replace(
      ~r/#.*$/,
      fn comment -> "\e[90m#{comment}\e[0m" end
    )
  end

  defp apply_syntax_highlighting(text, _), do: text

  defp render_status_bar(state, width) do
    left_info =
      " #{state.filename || "New File"}#{if state.modified, do: " *", else: ""} "

    right_info =
      " Ln #{state.cursor_row + 1}, Col #{state.cursor_col + 1} | #{state.file_type} "

    padding = width - String.length(left_info) - String.length(right_info)
    middle = String.duplicate(" ", max(0, padding))

    left_info <> middle <> right_info
  end

  defp render_command_bar(state, width) do
    prompt =
      case state.mode do
        :search -> "Search: "
        :save_as -> "Save as: "
        _ -> "> "
      end

    input = state.search_term || ""

    cursor =
      span(style: [bg: :white, fg: :black]) do
        " "
      end

    prompt <>
      input <>
      cursor <>
      String.duplicate(
        " ",
        width - String.length(prompt) - String.length(input) - 1
      )
  end

  # Terminal helpers

  defp setup_terminal do
    # Enable raw mode, hide cursor, etc.
    # Alternative screen buffer
    IO.write("\e[?1049h")
    # Hide cursor
    IO.write("\e[?25l")
    # Clear screen
    IO.write("\e[2J")
    # Move to top
    IO.write("\e[H")
  end

  defp terminal_size do
    case :io.columns() do
      {:ok, width} ->
        case :io.rows() do
          {:ok, height} -> {width, height}
          _ -> {80, 24}
        end

      _ ->
        {80, 24}
    end
  end
end

# Start the editor
Examples.Editor.NanoClone.start(System.argv())
