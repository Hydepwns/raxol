defmodule TerminalEditor do
  @moduledoc """
  Vi-like terminal text editor built with Raxol.

  A comprehensive example demonstrating:
  - Complex state management
  - Keyboard handling and modal editing
  - File operations and buffer management
  - Multi-mode user interface
  - Performance optimization for large files

  ## Features

  * Vi-style modal editing (normal, insert, visual modes)
  * File management (open, save, new, close)
  * Multi-buffer support with tabs
  * Syntax highlighting for common languages
  * Search and replace functionality
  * Undo/redo with history tracking
  * Line numbers and status bar
  * Split panes and window management
  * Configuration and theming

  ## Usage

      # Start editor
      TerminalEditor.start()
      
      # Open specific file
      TerminalEditor.start("path/to/file.txt")
      
      # Start with multiple files
      TerminalEditor.start(["file1.txt", "file2.txt"])

  ## Key Bindings

  ### Normal Mode
  * `h/j/k/l` - Move cursor left/down/up/right
  * `w/b` - Move word forward/backward
  * `0/$` - Move to beginning/end of line
  * `gg/G` - Move to first/last line
  * `i/a` - Enter insert mode before/after cursor
  * `o/O` - Open new line below/above
  * `dd` - Delete line
  * `yy` - Copy line
  * `p/P` - Paste after/before cursor
  * `u` - Undo
  * `Ctrl+r` - Redo
  * `/` - Search forward
  * `?` - Search backward
  * `:` - Command mode

  ### Command Mode
  * `:w` - Save file
  * `:q` - Quit
  * `:wq` - Save and quit
  * `:e <file>` - Open file
  * `:split` - Split window horizontally
  * `:vsplit` - Split window vertically
  """

  use Raxol.UI, framework: :universal
  require Logger

  alias TerminalEditor.{
    State,
    Buffer,
    Cursor,
    KeyHandler,
    FileManager,
    SearchEngine,
    SyntaxHighlighter,
    CommandProcessor,
    WindowManager
  }

  @default_config %{
    line_numbers: true,
    syntax_highlighting: true,
    tab_width: 2,
    wrap_lines: false,
    theme: :default,
    auto_save: false,
    backup_files: true
  }

  # Public API

  @doc """
  Start the terminal editor.
  """
  def start(files \\ [], opts \\ []) do
    config = Keyword.get(opts, :config, @default_config)

    initial_state = %State{
      mode: :normal,
      buffers: initialize_buffers(files),
      current_buffer: 0,
      cursor: %Cursor{row: 0, col: 0},
      windows: WindowManager.new(),
      config: config,
      status_message: "Welcome to Terminal Editor",
      command_buffer: "",
      search_query: "",
      clipboard: [],
      undo_stack: [],
      redo_stack: []
    }

    case Raxol.UI.start_link(__MODULE__, initial_state) do
      {:ok, pid} ->
        Logger.info("Terminal Editor started")
        run_editor_loop(pid)

      {:error, reason} ->
        Logger.error("Failed to start editor: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Stop the terminal editor.
  """
  def stop(pid) do
    Raxol.UI.stop(pid)
  end

  # UI Implementation

  @impl Raxol.UI
  def render(assigns) do
    ~H"""
    <div class="editor-container">
      <%= render_header(assigns) %>
      <%= render_main_area(assigns) %>
      <%= render_status_bar(assigns) %>
      <%= render_command_line(assigns) %>
    </div>
    """
  end

  defp render_header(assigns) do
    ~H"""
    <div class="editor-header">
      <%= render_tabs(assigns) %>
    </div>
    """
  end

  defp render_tabs(assigns) do
    ~H"""
    <div class="tabs">
      <%= for {buffer, index} <- Enum.with_index(@buffers) do %>
        <div class={tab_class(index, @current_buffer, buffer)}>
          <%= buffer_display_name(buffer) %>
          <%= if buffer.modified do %>
            <span class="modified-indicator">*</span>
          <% end %>
        </div>
      <% end %>
      
      <%= if length(@buffers) < 10 do %>
        <div class="new-tab-button" onclick={&handle_new_tab/0}>+</div>
      <% end %>
    </div>
    """
  end

  defp render_main_area(assigns) do
    ~H"""
    <div class="main-area">
      <%= render_editor_content(assigns) %>
    </div>
    """
  end

  defp render_editor_content(assigns) do
    current_buffer = get_current_buffer(assigns)

    ~H"""
    <div class="editor-content">
      <%= render_line_numbers(assigns, current_buffer) %>
      <%= render_text_area(assigns, current_buffer) %>
      <%= render_cursor(assigns) %>
      <%= render_selection(assigns) %>
    </div>
    """
  end

  defp render_line_numbers(assigns, buffer) do
    return(if(not assigns.config.line_numbers))

    ~H"""
    <div class="line-numbers">
      <%= for {_line, line_num} <- Enum.with_index(buffer.lines, 1) do %>
        <div class="line-number"><%= line_num %></div>
      <% end %>
    </div>
    """
  end

  defp render_text_area(assigns, buffer) do
    visible_lines = calculate_visible_lines(buffer, assigns)

    ~H"""
    <div class="text-area" onkeydown={&handle_keydown/1}>
      <%= for {line, line_index} <- visible_lines do %>
        <div class="editor-line">
          <%= render_line_content(line, line_index, assigns) %>
        </div>
      <% end %>
    </div>
    """
  end

  defp render_line_content(line, line_index, assigns) do
    if assigns.config.syntax_highlighting do
      render_highlighted_line(line, line_index, assigns)
    else
      render_plain_line(line, line_index, assigns)
    end
  end

  defp render_highlighted_line(line, line_index, assigns) do
    current_buffer = get_current_buffer(assigns)
    language = detect_language(current_buffer.file_path)

    highlighted = SyntaxHighlighter.highlight(line, language)

    ~H"""
    <span class="highlighted-line">
      <%= for token <- highlighted do %>
        <span class={token_class(token.type)}><%= token.text %></span>
      <% end %>
    </span>
    """
  end

  defp render_plain_line(line, _line_index, _assigns) do
    ~H"""
    <span class="plain-line"><%= line %></span>
    """
  end

  defp render_cursor(assigns) do
    return(
      if(
        assigns.mode == :insert and
          :timer.tc(fn -> true end) |> elem(0) |> rem(1_000_000) < 500_000
      )
    )

    ~H"""
    <div 
      class={cursor_class(assigns)}
      style={cursor_position_style(assigns)}
    >
    </div>
    """
  end

  defp render_selection(assigns) do
    return(unless(assigns.mode == :visual))

    selection_range = calculate_selection_range(assigns)

    ~H"""
    <div class="selection-overlay">
      <%= for {start_pos, end_pos} <- selection_range do %>
        <div 
          class="selection-block"
          style={selection_style(start_pos, end_pos)}
        >
        </div>
      <% end %>
    </div>
    """
  end

  defp render_status_bar(assigns) do
    current_buffer = get_current_buffer(assigns)

    ~H"""
    <div class="status-bar">
      <div class="status-left">
        <span class="mode-indicator"><%= mode_display(@mode) %></span>
        <span class="file-info">
          <%= current_buffer.file_path || "[No Name]" %>
          <%= if current_buffer.modified, do: " [Modified]", else: "" %>
        </span>
      </div>
      
      <div class="status-center">
        <%= @status_message %>
      </div>
      
      <div class="status-right">
        <span class="position-info">
          <%= @cursor.row + 1 %>:<%= @cursor.col + 1 %>
        </span>
        <span class="file-stats">
          <%= length(current_buffer.lines) %> lines
        </span>
        <span class="encoding">UTF-8</span>
      </div>
    </div>
    """
  end

  defp render_command_line(assigns) do
    return(unless(assigns.mode in [:command, :search]))

    prompt =
      case assigns.mode do
        :command -> ":"
        :search -> "/"
      end

    ~H"""
    <div class="command-line">
      <span class="command-prompt"><%= prompt %></span>
      <input 
        type="text" 
        value={@command_buffer}
        class="command-input"
        oninput={&handle_command_input/1}
        onkeydown={&handle_command_keydown/1}
        autofocus
      />
    </div>
    """
  end

  # Event Handlers

  defp handle_keydown(%{key: key, ctrl: ctrl, alt: alt, shift: shift}, state) do
    KeyHandler.handle_key(state, %{
      key: key,
      ctrl: ctrl,
      alt: alt,
      shift: shift
    })
  end

  defp handle_command_input(%{value: value}, state) do
    {:ok, %{state | command_buffer: value}}
  end

  defp handle_command_keydown(%{key: "Enter"}, state) do
    case state.mode do
      :command ->
        CommandProcessor.execute_command(state.command_buffer, state)

      :search ->
        SearchEngine.perform_search(state.command_buffer, state)
    end
  end

  defp handle_command_keydown(%{key: "Escape"}, state) do
    {:ok, %{state | mode: :normal, command_buffer: ""}}
  end

  defp handle_new_tab(state) do
    new_buffer = Buffer.new()
    new_buffers = state.buffers ++ [new_buffer]

    {:ok,
     %{
       state
       | buffers: new_buffers,
         current_buffer: length(new_buffers) - 1,
         status_message: "New buffer created"
     }}
  end

  # Helper Functions

  defp initialize_buffers([]) do
    [Buffer.new()]
  end

  defp initialize_buffers(files) when is_list(files) do
    Enum.map(files, &load_file_to_buffer/1)
  end

  defp initialize_buffers(file) when is_binary(file) do
    [load_file_to_buffer(file)]
  end

  defp load_file_to_buffer(file_path) do
    case File.read(file_path) do
      {:ok, content} ->
        lines = String.split(content, ["\n", "\r\n"])

        %Buffer{
          file_path: file_path,
          lines: lines,
          modified: false
        }

      {:error, reason} ->
        Logger.warning("Failed to load file #{file_path}: #{reason}")

        %Buffer{
          file_path: file_path,
          lines: [""],
          modified: false,
          error: "Failed to load: #{reason}"
        }
    end
  end

  defp get_current_buffer(assigns) do
    Enum.at(assigns.buffers, assigns.current_buffer)
  end

  defp buffer_display_name(buffer) do
    case buffer.file_path do
      nil -> "[No Name]"
      path -> Path.basename(path)
    end
  end

  defp tab_class(index, current_index, buffer) do
    classes = ["tab"]

    classes =
      if index == current_index do
        ["active" | classes]
      else
        classes
      end

    classes =
      if buffer.modified do
        ["modified" | classes]
      else
        classes
      end

    Enum.join(classes, " ")
  end

  defp calculate_visible_lines(buffer, assigns) do
    # Calculate which lines are visible in the current viewport
    # This would come from terminal size detection
    terminal_height = 40
    header_height = 2
    status_height = 2
    available_height = terminal_height - header_height - status_height

    start_line = max(0, assigns.cursor.row - div(available_height, 2))
    end_line = min(length(buffer.lines), start_line + available_height)

    buffer.lines
    |> Enum.slice(start_line, end_line - start_line)
    |> Enum.with_index(start_line)
  end

  defp detect_language(nil), do: :plain

  defp detect_language(file_path) do
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
      ".cpp" -> :cpp
      ".h" -> :c
      ".java" -> :java
      ".md" -> :markdown
      ".json" -> :json
      ".yaml" -> :yaml
      ".yml" -> :yaml
      ".toml" -> :toml
      ".html" -> :html
      ".css" -> :css
      ".scss" -> :scss
      ".xml" -> :xml
      _ -> :plain
    end
  end

  defp token_class(type) do
    case type do
      :keyword -> "token-keyword"
      :string -> "token-string"
      :comment -> "token-comment"
      :number -> "token-number"
      :operator -> "token-operator"
      :identifier -> "token-identifier"
      :function -> "token-function"
      _ -> "token-default"
    end
  end

  defp cursor_class(assigns) do
    classes = ["cursor"]

    classes =
      case assigns.mode do
        :normal -> ["cursor-normal" | classes]
        :insert -> ["cursor-insert" | classes]
        :visual -> ["cursor-visual" | classes]
        _ -> classes
      end

    Enum.join(classes, " ")
  end

  defp cursor_position_style(assigns) do
    # Calculate pixel position based on character position
    # Monospace character width
    char_width = 8
    # Line height
    line_height = 16

    left = assigns.cursor.col * char_width
    top = assigns.cursor.row * line_height

    "left: #{left}px; top: #{top}px;"
  end

  defp calculate_selection_range(_assigns) do
    # Calculate visual selection ranges
    # This would be more complex in a real implementation
    []
  end

  defp selection_style(_start_pos, _end_pos) do
    "/* selection styling */"
  end

  defp mode_display(mode) do
    case mode do
      :normal -> "NORMAL"
      :insert -> "INSERT"
      :visual -> "VISUAL"
      :command -> "COMMAND"
      :search -> "SEARCH"
      _ -> String.upcase(to_string(mode))
    end
  end

  defp run_editor_loop(pid) do
    receive do
      {:stop} ->
        stop(pid)

      {:refresh} ->
        Raxol.UI.refresh(pid)
        run_editor_loop(pid)

      other ->
        Logger.debug("Editor loop received: #{inspect(other)}")
        run_editor_loop(pid)
    end
  end
end
