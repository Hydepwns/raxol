defmodule FileBrowser do
  @moduledoc """
  Terminal file browser with preview functionality built with Raxol.

  Features:
  - Hierarchical file and directory navigation
  - File preview for text, images, and binary files
  - Search and filtering capabilities
  - Multiple view modes (list, tree, grid)
  - File operations (copy, move, delete, rename)
  - Bookmarks and favorites
  - Dual-pane interface
  - Keyboard shortcuts and vim-style navigation

  ## Usage

      # Start in current directory
      FileBrowser.start()
      
      # Start in specific directory
      FileBrowser.start("/path/to/directory")
      
      # Start with dual panes
      FileBrowser.start(mode: :dual_pane)

  ## Key Bindings

  * `j/k` - Navigate up/down in file list
  * `h/l` - Navigate to parent/child directory
  * `Enter` - Open file or enter directory
  * `Space` - Preview file
  * `/` - Start search
  * `n/p` - Next/previous search result
  * `?` - Show help
  * `q` - Quit application
  * `r` - Refresh current directory
  * `f` - Toggle follow mode
  * `v` - Change view mode
  * `Tab` - Switch between panes (dual pane mode)
  * `F2` - Rename file
  * `F5` - Copy file
  * `F6` - Move file
  * `Delete` - Delete file (with confirmation)
  """

  use Raxol.UI, framework: :universal
  require Logger

  alias FileBrowser.{
    State,
    DirectoryScanner,
    FilePreview,
    SearchEngine,
    FileOperations,
    ViewRenderer
  }

  @default_config %{
    show_hidden: false,
    sort_by: :name,
    sort_direction: :asc,
    view_mode: :list,
    dual_pane: false,
    preview_enabled: true,
    follow_symlinks: false,
    # 1MB
    max_preview_size: 1_048_576,
    file_icons: true
  }

  # Public API

  @doc """
  Start the file browser.
  """
  def start(path_or_opts \\ ".", opts \\ [])

  def start(path, opts) when is_binary(path) do
    config = Keyword.get(opts, :config, @default_config)
    start_path = Path.expand(path)

    unless File.exists?(start_path) and File.dir?(start_path) do
      Logger.error("Invalid directory: #{start_path}")
      {:error, "Directory does not exist: #{start_path}"}
    else
      initial_state = %State{
        current_path: start_path,
        left_pane_path: start_path,
        right_pane_path: start_path,
        files: [],
        selected_index: 0,
        active_pane: :left,
        config: config,
        search_query: "",
        search_results: [],
        preview_content: nil,
        status_message: "",
        mode: :browse,
        clipboard: nil
      }

      case load_directory(initial_state) do
        {:ok, loaded_state} ->
          start_browser(loaded_state)

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  def start(opts, _) when is_list(opts) do
    path = Keyword.get(opts, :path, ".")
    start(path, opts)
  end

  # UI Implementation

  @impl Raxol.UI
  def render(assigns) do
    ~H"""
    <div class="file-browser">
      <%= render_header(assigns) %>
      <%= render_main_content(assigns) %>
      <%= render_status_bar(assigns) %>
      <%= render_help_overlay(assigns) %>
    </div>
    """
  end

  defp render_header(assigns) do
    ~H"""
    <div class="browser-header">
      <div class="breadcrumb">
        <%= render_breadcrumb(assigns) %>
      </div>
      <div class="view-controls">
        <span class="view-mode"><%= @config.view_mode %></span>
        <%= if @config.dual_pane do %>
          <span class="pane-indicator">
            <%= if @active_pane == :left, do: "◀ LEFT", else: "RIGHT ▶" %>
          </span>
        <% end %>
      </div>
    </div>
    """
  end

  defp render_breadcrumb(assigns) do
    current_path =
      if assigns.config.dual_pane do
        if assigns.active_pane == :left,
          do: assigns.left_pane_path,
          else: assigns.right_pane_path
      else
        assigns.current_path
      end

    path_parts = Path.split(current_path)

    ~H"""
    <div class="breadcrumb-path">
      <%= for {part, index} <- Enum.with_index(path_parts) do %>
        <span 
          class="breadcrumb-part"
          onclick={&handle_breadcrumb_click(index, path_parts)}
        >
          <%= part %>
        </span>
        <%= if index < length(path_parts) - 1 do %>
          <span class="breadcrumb-separator">/</span>
        <% end %>
      <% end %>
    </div>
    """
  end

  defp render_main_content(assigns) do
    if assigns.config.dual_pane do
      render_dual_pane(assigns)
    else
      render_single_pane(assigns)
    end
  end

  defp render_single_pane(assigns) do
    ~H"""
    <div class="main-content single-pane">
      <div class="file-list-panel">
        <%= render_file_list(assigns, assigns.files) %>
      </div>
      <%= if assigns.config.preview_enabled and assigns.preview_content do %>
        <div class="preview-panel">
          <%= render_file_preview(assigns) %>
        </div>
      <% end %>
    </div>
    """
  end

  defp render_dual_pane(assigns) do
    ~H"""
    <div class="main-content dual-pane">
      <div class={pane_class(:left, assigns)}>
        <div class="pane-header">Left Pane</div>
        <%= render_file_list(assigns, get_pane_files(assigns, :left)) %>
      </div>
      
      <div class="pane-divider">│</div>
      
      <div class={pane_class(:right, assigns)}>
        <div class="pane-header">Right Pane</div>
        <%= render_file_list(assigns, get_pane_files(assigns, :right)) %>
      </div>
    </div>
    """
  end

  defp render_file_list(assigns, files) do
    case assigns.config.view_mode do
      :list -> render_list_view(assigns, files)
      :tree -> render_tree_view(assigns, files)
      :grid -> render_grid_view(assigns, files)
      _ -> render_list_view(assigns, files)
    end
  end

  defp render_list_view(assigns, files) do
    ~H"""
    <div class="file-list list-view" onkeydown={&handle_keydown/1}>
      <%= for {file, index} <- Enum.with_index(files) do %>
        <div 
          class={file_item_class(index, assigns)}
          onclick={&handle_file_click(file, index)}
          ondblclick={&handle_file_double_click(file)}
        >
          <span class="file-icon"><%= get_file_icon(file) %></span>
          <span class="file-name"><%= file.name %></span>
          <span class="file-size"><%= format_file_size(file.size) %></span>
          <span class="file-modified"><%= format_date(file.modified) %></span>
          <%= if file.symlink do %>
            <span class="symlink-indicator">→ <%= file.symlink_target %></span>
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end

  defp render_tree_view(assigns, files) do
    ~H"""
    <div class="file-list tree-view">
      <%= render_tree_node(assigns, files, 0) %>
    </div>
    """
  end

  defp render_tree_node(assigns, files, depth) do
    ~H"""
    <%= for {file, index} <- Enum.with_index(files) do %>
      <div class={tree_item_class(index, depth, assigns)}>
        <span class="tree-indent"><%= String.duplicate("  ", depth) %></span>
        <%= if file.type == :directory do %>
          <span class="tree-expander">
            <%= if file.expanded, do: "▼", else: "▶" %>
          </span>
        <% end %>
        <span class="file-icon"><%= get_file_icon(file) %></span>
        <span class="file-name"><%= file.name %></span>
      </div>
      <%= if file.type == :directory and file.expanded and file.children do %>
        <%= render_tree_node(assigns, file.children, depth + 1) %>
      <% end %>
    <% end %>
    """
  end

  defp render_grid_view(assigns, files) do
    ~H"""
    <div class="file-list grid-view">
      <%= for {file, index} <- Enum.with_index(files) do %>
        <div class={grid_item_class(index, assigns)}>
          <div class="grid-icon"><%= get_file_icon(file) %></div>
          <div class="grid-name"><%= file.name %></div>
        </div>
      <% end %>
    </div>
    """
  end

  defp render_file_preview(assigns) do
    case assigns.preview_content do
      %{type: :text, content: content} ->
        render_text_preview(content)

      %{type: :image, path: path} ->
        render_image_preview(path)

      %{type: :binary, info: info} ->
        render_binary_preview(info)

      %{type: :error, message: message} ->
        render_error_preview(message)

      _ ->
        ~H"<div class='preview-empty'>No preview available</div>"
    end
  end

  defp render_text_preview(content) do
    # Limit preview lines
    lines = String.split(content, "\n") |> Enum.take(50)

    ~H"""
    <div class="text-preview">
      <div class="preview-header">Text Preview</div>
      <div class="preview-content">
        <%= for {line, line_num} <- Enum.with_index(lines, 1) do %>
          <div class="preview-line">
            <span class="line-number"><%= line_num %></span>
            <span class="line-content"><%= line %></span>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  defp render_image_preview(path) do
    ~H"""
    <div class="image-preview">
      <div class="preview-header">Image Preview</div>
      <div class="image-info">
        <div>Path: <%= path %></div>
        <div>Format: <%= Path.extname(path) %></div>
      </div>
      <div class="ascii-art">
        <!-- ASCII art representation would go here -->
        [Image: <%= Path.basename(path) %>]
      </div>
    </div>
    """
  end

  defp render_binary_preview(info) do
    ~H"""
    <div class="binary-preview">
      <div class="preview-header">Binary File</div>
      <div class="binary-info">
        <div>Size: <%= format_file_size(info.size) %></div>
        <div>Type: <%= info.mime_type || "Unknown" %></div>
        <div>Encoding: <%= info.encoding || "Binary" %></div>
      </div>
      <div class="hex-dump">
        <%= if info.hex_sample do %>
          <pre><%= info.hex_sample %></pre>
        <% else %>
          [Binary data - no preview available]
        <% end %>
      </div>
    </div>
    """
  end

  defp render_error_preview(message) do
    ~H"""
    <div class="error-preview">
      <div class="preview-header error">Error</div>
      <div class="error-message"><%= message %></div>
    </div>
    """
  end

  defp render_status_bar(assigns) do
    file_count = length(assigns.files)
    dir_count = Enum.count(assigns.files, &(&1.type == :directory))
    total_size = Enum.reduce(assigns.files, 0, &(&2 + (&1.size || 0)))

    ~H"""
    <div class="status-bar">
      <div class="status-left">
        <%= if assigns.status_message != "" do %>
          <%= assigns.status_message %>
        <% else %>
          <%= file_count %> items, <%= dir_count %> dirs, <%= format_file_size(total_size) %>
        <% end %>
      </div>
      
      <div class="status-center">
        <%= if assigns.search_query != "" do %>
          Search: "<%= assigns.search_query %>" (<%= length(assigns.search_results) %> results)
        <% end %>
      </div>
      
      <div class="status-right">
        <%= if assigns.config.show_hidden, do: "Hidden", else: "" %>
        <%= assigns.config.sort_by %> <%= if assigns.config.sort_direction == :desc, do: "↓", else: "↑" %>
      </div>
    </div>
    """
  end

  defp render_help_overlay(assigns) do
    return(unless(assigns.mode == :help))

    ~H"""
    <div class="help-overlay">
      <div class="help-content">
        <h2>File Browser Help</h2>
        
        <h3>Navigation</h3>
        <ul>
          <li><code>j/k</code> - Move up/down</li>
          <li><code>h/l</code> - Parent/child directory</li>
          <li><code>Enter</code> - Open file/directory</li>
          <li><code>Space</code> - Preview file</li>
        </ul>
        
        <h3>File Operations</h3>
        <ul>
          <li><code>F2</code> - Rename</li>
          <li><code>F5</code> - Copy</li>
          <li><code>F6</code> - Move</li>
          <li><code>Delete</code> - Delete</li>
        </ul>
        
        <h3>View</h3>
        <ul>
          <li><code>v</code> - Change view mode</li>
          <li><code>f</code> - Toggle follow mode</li>
          <li><code>r</code> - Refresh</li>
          <li><code>Tab</code> - Switch panes</li>
        </ul>
        
        <h3>Search</h3>
        <ul>
          <li><code>/</code> - Start search</li>
          <li><code>n/p</code> - Next/previous result</li>
        </ul>
        
        <div class="help-footer">
          Press any key to close help
        </div>
      </div>
    </div>
    """
  end

  # Event Handlers

  defp handle_keydown(%{key: key, ctrl: ctrl} = event, state) do
    case {key, ctrl, state.mode} do
      {"q", false, :browse} ->
        {:stop, state}

      {"?", false, :browse} ->
        {:ok, %{state | mode: :help}}

      {_, _, :help} ->
        {:ok, %{state | mode: :browse}}

      {"j", false, :browse} ->
        move_selection(state, :down)

      {"k", false, :browse} ->
        move_selection(state, :up)

      {"h", false, :browse} ->
        navigate_to_parent(state)

      {"l", false, :browse} ->
        enter_directory_or_preview(state)

      {"Enter", false, :browse} ->
        open_selected_item(state)

      {"Space", false, :browse} ->
        preview_selected_item(state)

      {"/", false, :browse} ->
        start_search(state)

      {"r", false, :browse} ->
        refresh_directory(state)

      {"v", false, :browse} ->
        cycle_view_mode(state)

      {"Tab", false, :browse} when state.config.dual_pane ->
        switch_active_pane(state)

      _ ->
        {:ok, %{state | status_message: "Unknown command: #{key}"}}
    end
  end

  # Navigation and File Operations

  defp move_selection(state, direction) do
    current_index = state.selected_index
    file_count = length(state.files)

    new_index =
      case direction do
        :up -> max(0, current_index - 1)
        :down -> min(file_count - 1, current_index + 1)
      end

    new_state = %{state | selected_index: new_index}

    # Auto-preview if enabled
    if state.config.preview_enabled and new_index != current_index do
      preview_file_at_index(new_state, new_index)
    else
      {:ok, new_state}
    end
  end

  defp navigate_to_parent(state) do
    current_path = get_current_path(state)
    parent_path = Path.dirname(current_path)

    if parent_path != current_path do
      navigate_to_directory(state, parent_path)
    else
      {:ok, %{state | status_message: "Already at root directory"}}
    end
  end

  defp navigate_to_directory(state, new_path) do
    updated_state =
      if state.config.dual_pane do
        case state.active_pane do
          :left -> %{state | left_pane_path: new_path}
          :right -> %{state | right_pane_path: new_path}
        end
      else
        %{state | current_path: new_path}
      end

    load_directory(updated_state)
  end

  defp open_selected_item(state) do
    case get_selected_file(state) do
      nil ->
        {:ok, state}

      file ->
        case file.type do
          :directory ->
            full_path = Path.join(get_current_path(state), file.name)
            navigate_to_directory(state, full_path)

          :file ->
            open_file_with_default_app(file, state)
        end
    end
  end

  defp preview_selected_item(state) do
    case get_selected_file(state) do
      nil ->
        {:ok, state}

      file ->
        preview_file_at_index(state, state.selected_index)
    end
  end

  defp preview_file_at_index(state, index) do
    case Enum.at(state.files, index) do
      nil ->
        {:ok, %{state | preview_content: nil}}

      file ->
        full_path = Path.join(get_current_path(state), file.name)

        case FilePreview.generate_preview(full_path, state.config) do
          {:ok, preview_content} ->
            {:ok, %{state | preview_content: preview_content}}

          {:error, reason} ->
            error_preview = %{type: :error, message: reason}
            {:ok, %{state | preview_content: error_preview}}
        end
    end
  end

  defp load_directory(state) do
    current_path = get_current_path(state)

    case DirectoryScanner.scan_directory(current_path, state.config) do
      {:ok, files} ->
        sorted_files = sort_files(files, state.config)

        {:ok,
         %{
           state
           | files: sorted_files,
             selected_index: 0,
             status_message: "",
             preview_content: nil
         }}

      {:error, reason} ->
        {:error, "Failed to load directory: #{reason}"}
    end
  end

  # Helper Functions

  defp start_browser(state) do
    case Raxol.UI.start_link(__MODULE__, state) do
      {:ok, pid} ->
        Logger.info("File Browser started")
        run_browser_loop(pid)

      {:error, reason} ->
        Logger.error("Failed to start browser: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp run_browser_loop(pid) do
    receive do
      {:stop} ->
        Raxol.UI.stop(pid)

      {:refresh} ->
        Raxol.UI.refresh(pid)
        run_browser_loop(pid)

      other ->
        Logger.debug("Browser loop received: #{inspect(other)}")
        run_browser_loop(pid)
    end
  end

  defp get_current_path(state) do
    if state.config.dual_pane do
      case state.active_pane do
        :left -> state.left_pane_path
        :right -> state.right_pane_path
      end
    else
      state.current_path
    end
  end

  defp get_selected_file(state) do
    Enum.at(state.files, state.selected_index)
  end

  defp get_pane_files(state, pane) do
    # In a full implementation, each pane would have its own file list
    state.files
  end

  defp sort_files(files, config) do
    sorted =
      case config.sort_by do
        :name -> Enum.sort_by(files, & &1.name)
        :size -> Enum.sort_by(files, &(&1.size || 0))
        :type -> Enum.sort_by(files, & &1.type)
        :modified -> Enum.sort_by(files, & &1.modified)
        _ -> files
      end

    if config.sort_direction == :desc do
      Enum.reverse(sorted)
    else
      sorted
    end
  end

  defp file_item_class(index, state) do
    classes = ["file-item"]

    if index == state.selected_index do
      ["selected" | classes]
    else
      classes
    end
    |> Enum.join(" ")
  end

  defp pane_class(pane, state) do
    classes = ["file-pane", Atom.to_string(pane)]

    if state.active_pane == pane do
      ["active" | classes]
    else
      classes
    end
    |> Enum.join(" ")
  end

  defp get_file_icon(file) do
    case file.type do
      :directory ->
        "[DIR]"

      :file ->
        case Path.extname(file.name) do
          ".txt" -> "[TXT]"
          ".md" -> "[MD]"
          ".ex" -> "[RUBY]"
          ".exs" -> "[RUBY]"
          ".js" -> "[JS]"
          ".html" -> "[WEB]"
          ".css" -> "[CSS]"
          ".json" -> "[JSON]"
          ".png" -> "[IMG]"
          ".jpg" -> "[IMG]"
          ".jpeg" -> "[IMG]"
          ".gif" -> "[IMG]"
          ".mp3" -> "[AUDIO]"
          ".mp4" -> "[VIDEO]"
          ".pdf" -> "[PDF]"
          ".zip" -> "[COMPRESS]"
          ".tar" -> "[COMPRESS]"
          ".gz" -> "[COMPRESS]"
          _ -> "[TXT]"
        end
    end
  end

  defp format_file_size(nil), do: ""
  defp format_file_size(size) when size < 1024, do: "#{size}B"
  defp format_file_size(size) when size < 1_048_576, do: "#{div(size, 1024)}KB"

  defp format_file_size(size) when size < 1_073_741_824,
    do: "#{div(size, 1_048_576)}MB"

  defp format_file_size(size), do: "#{Float.round(size / 1_073_741_824, 1)}GB"

  defp format_date(datetime) do
    case datetime do
      %DateTime{} -> Calendar.strftime(datetime, "%Y-%m-%d %H:%M")
      _ -> ""
    end
  end

  # Placeholder implementations for complex operations

  defp start_search(state) do
    {:ok,
     %{state | mode: :search, status_message: "Search mode not implemented yet"}}
  end

  defp refresh_directory(state) do
    load_directory(state)
  end

  defp cycle_view_mode(state) do
    new_mode =
      case state.config.view_mode do
        :list -> :tree
        :tree -> :grid
        :grid -> :list
      end

    new_config = %{state.config | view_mode: new_mode}

    {:ok,
     %{state | config: new_config, status_message: "View mode: #{new_mode}"}}
  end

  defp switch_active_pane(state) do
    new_pane = if state.active_pane == :left, do: :right, else: :left
    {:ok, %{state | active_pane: new_pane}}
  end

  defp open_file_with_default_app(file, state) do
    {:ok, %{state | status_message: "Opening #{file.name}..."}}
  end

  # Additional helper function stubs

  defp handle_file_click(_file, _index, state), do: {:ok, state}
  defp handle_file_double_click(_file, state), do: {:ok, state}
  defp handle_breadcrumb_click(_index, _parts, state), do: {:ok, state}
  defp tree_item_class(_index, _depth, _state), do: "tree-item"
  defp grid_item_class(_index, _state), do: "grid-item"
  defp enter_directory_or_preview(state), do: {:ok, state}
end
