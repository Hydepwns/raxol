defmodule Raxol.Plugins.Examples.FileBrowserPlugin do
  @moduledoc """
  File Browser Plugin for Raxol Terminal

  Provides a tree-style file browser with navigation and file operations.
  Demonstrates:
  - File system interaction
  - Tree rendering
  - Keyboard navigation
  - File operations (open, create, delete, rename)
  - State management
  - Icon support
  """

  use Raxol.Core.Behaviours.BaseManager
  alias Raxol.Core.Runtime.Log
  # Plugin Manifest
  def manifest do
    %{
      name: "file-browser",
      version: "1.0.0",
      description: "Tree-style file browser with navigation",
      author: "Raxol Team",
      dependencies: %{
        "raxol-core" => "~> 1.5"
      },
      capabilities: [
        :file_system,
        :ui_panel,
        :keyboard_input
      ],
      config_schema: %{
        initial_path: %{type: :string, default: "."},
        show_hidden: %{type: :boolean, default: false},
        show_icons: %{type: :boolean, default: true},
        panel_width: %{type: :integer, default: 30},
        position: %{type: :string, default: "left", enum: ["left", "right"]},
        hotkey: %{type: :string, default: "ctrl+b"}
      }
    }
  end

  # Plugin State
  defstruct [
    :config,
    :current_path,
    :entries,
    :selected_index,
    :expanded_dirs,
    :is_open,
    :emulator_pid,
    :scroll_offset,
    :panel_height,
    :filter_pattern
  ]

  # File Entry Structure
  defmodule Entry do
    @moduledoc """
    File system entry structure for the file browser.

    Represents a file or directory with name, path, type, size, modification time,
    permissions, and optional children for directories.
    """
    defstruct [
      :name,
      :path,
      :type,
      :size,
      :modified,
      :permissions,
      :children,
      :expanded
    ]
  end

  # Initialization
  @impl true
  def init_manager(config) do
    Log.info("Initializing with config: #{inspect(config)}")

    initial_path = Path.expand(config.initial_path || ".")

    state = %__MODULE__{
      config: config,
      current_path: initial_path,
      entries: load_directory(initial_path, config.show_hidden),
      selected_index: 0,
      expanded_dirs: MapSet.new([initial_path]),
      is_open: false,
      emulator_pid: nil,
      scroll_offset: 0,
      panel_height: 24,
      filter_pattern: nil
    }

    {:ok, state}
  end

  # Hot-reload support
  def preserve_state(state) do
    %{
      current_path: state.current_path,
      selected_index: state.selected_index,
      expanded_dirs: state.expanded_dirs,
      is_open: state.is_open,
      scroll_offset: state.scroll_offset,
      filter_pattern: state.filter_pattern
    }
  end

  def restore_state(preserved_state, new_config) do
    %__MODULE__{
      config: new_config,
      current_path: preserved_state.current_path,
      entries:
        load_directory(preserved_state.current_path, new_config.show_hidden),
      selected_index: preserved_state.selected_index || 0,
      expanded_dirs: preserved_state.expanded_dirs || MapSet.new(),
      is_open: preserved_state.is_open || false,
      emulator_pid: nil,
      scroll_offset: preserved_state.scroll_offset || 0,
      panel_height: 24,
      filter_pattern: preserved_state.filter_pattern
    }
  end

  # Event Handlers
  def handle_event({:keyboard, "ctrl+b"}, state) do
    toggle_browser(state)
  end

  def handle_event({:keyboard, "escape"}, %{is_open: true} = state) do
    close_browser(state)
  end

  def handle_event({:keyboard, "enter"}, %{is_open: true} = state) do
    handle_selection(state)
  end

  def handle_event({:keyboard, "up"}, %{is_open: true} = state) do
    navigate(state, :up)
  end

  def handle_event({:keyboard, "down"}, %{is_open: true} = state) do
    navigate(state, :down)
  end

  def handle_event({:keyboard, "left"}, %{is_open: true} = state) do
    collapse_or_navigate_up(state)
  end

  def handle_event({:keyboard, "right"}, %{is_open: true} = state) do
    expand_or_enter(state)
  end

  def handle_event({:keyboard, "h"}, %{is_open: true} = state) do
    toggle_hidden(state)
  end

  def handle_event({:keyboard, "/"}, %{is_open: true} = state) do
    start_filter(state)
  end

  def handle_event({:keyboard, "n"}, %{is_open: true} = state) do
    create_file_prompt(state)
  end

  def handle_event({:keyboard, "d"}, %{is_open: true} = state) do
    delete_file_prompt(state)
  end

  def handle_event({:keyboard, "r"}, %{is_open: true} = state) do
    rename_file_prompt(state)
  end

  def handle_event({:terminal_resize, {_width, height}}, state) do
    {:ok, %{state | panel_height: height}}
  end

  def handle_event(_event, state) do
    {:ok, state}
  end

  # File Operations
  defp load_directory(path, show_hidden) do
    case File.ls(path) do
      {:ok, files} ->
        files
        |> filter_files(show_hidden)
        |> Enum.map(fn name ->
          full_path = Path.join(path, name)
          build_entry(full_path, name)
        end)
        |> Enum.sort_by(fn entry ->
          {entry.type != :directory, String.downcase(entry.name)}
        end)

      {:error, _reason} ->
        []
    end
  end

  defp filter_files(files, false) do
    Enum.reject(files, &String.starts_with?(&1, "."))
  end

  defp filter_files(files, true), do: files

  defp build_entry(path, name) do
    case File.stat(path) do
      {:ok, stat} ->
        %Entry{
          name: name,
          path: path,
          type: stat.type,
          size: stat.size,
          modified: stat.mtime,
          permissions: nil,
          children: nil,
          expanded: false
        }

      {:error, _} ->
        %Entry{
          name: name,
          path: path,
          type: :unknown,
          size: 0,
          modified: nil,
          permissions: nil,
          children: nil,
          expanded: false
        }
    end
  end

  # Navigation
  defp navigate(state, :up) do
    new_index = max(0, state.selected_index - 1)

    new_state =
      %{state | selected_index: new_index}
      |> adjust_scroll()

    render_browser(new_state)
    {:ok, new_state}
  end

  defp navigate(state, :down) do
    flat_entries = flatten_tree(state.entries, state.expanded_dirs)
    max_index = length(flat_entries) - 1
    new_index = min(max_index, state.selected_index + 1)

    new_state =
      %{state | selected_index: new_index}
      |> adjust_scroll()

    render_browser(new_state)
    {:ok, new_state}
  end

  defp expand_or_enter(state) do
    flat_entries = flatten_tree(state.entries, state.expanded_dirs)

    case Enum.at(flat_entries, state.selected_index) do
      nil ->
        {:ok, state}

      %{type: :directory, path: path} = _entry ->
        # Toggle expansion
        expanded_dirs =
          case MapSet.member?(state.expanded_dirs, path) do
            true -> MapSet.delete(state.expanded_dirs, path)
            false -> MapSet.put(state.expanded_dirs, path)
          end

        # Reload entries if expanding
        entries =
          case MapSet.member?(expanded_dirs, path) do
            true ->
              reload_with_children(
                state.entries,
                path,
                state.config.show_hidden
              )

            false ->
              state.entries
          end

        new_state = %{state | expanded_dirs: expanded_dirs, entries: entries}
        render_browser(new_state)
        {:ok, new_state}

      %{type: :regular} = entry ->
        # Open file
        open_file(entry.path)
        {:ok, state}

      _ ->
        {:ok, state}
    end
  end

  defp collapse_or_navigate_up(state) do
    flat_entries = flatten_tree(state.entries, state.expanded_dirs)

    case Enum.at(flat_entries, state.selected_index) do
      %{type: :directory, path: path} ->
        case MapSet.member?(state.expanded_dirs, path) do
          true ->
            # Collapse directory
            expanded_dirs = MapSet.delete(state.expanded_dirs, path)
            new_state = %{state | expanded_dirs: expanded_dirs}
            render_browser(new_state)
            {:ok, new_state}

          false ->
            # Navigate to parent directory
            parent = Path.dirname(state.current_path)
            navigate_to_directory(state, parent)
        end

      _ ->
        # Navigate to parent
        parent = Path.dirname(state.current_path)
        navigate_to_directory(state, parent)
    end
  end

  defp navigate_to_directory(state, path) do
    expanded_path = Path.expand(path)
    entries = load_directory(expanded_path, state.config.show_hidden)

    new_state = %{
      state
      | current_path: expanded_path,
        entries: entries,
        selected_index: 0,
        scroll_offset: 0
    }

    render_browser(new_state)
    {:ok, new_state}
  end

  defp reload_with_children(entries, dir_path, show_hidden) do
    children = load_directory(dir_path, show_hidden)

    Enum.map(entries, fn entry ->
      case entry.path == dir_path do
        true -> %{entry | children: children, expanded: true}
        false -> entry
      end
    end)
  end

  # UI Rendering
  defp toggle_browser(state) do
    case state.is_open do
      true -> close_browser(state)
      false -> open_browser(state)
    end
  end

  defp open_browser(state) do
    new_state = %{state | is_open: true}
    render_browser(new_state)
    {:ok, new_state}
  end

  defp close_browser(state) do
    new_state = %{state | is_open: false}
    clear_panel(state.emulator_pid)
    {:ok, new_state}
  end

  defp render_browser(state) do
    panel_content = build_browser_ui(state)
    send_panel(state.emulator_pid, panel_content, state.config.position)
  end

  defp build_browser_ui(state) do
    width = state.config.panel_width || 30
    height = state.panel_height

    # Header
    header = build_header(state.current_path, width)

    # File tree
    flat_entries = flatten_tree(state.entries, state.expanded_dirs, 0)

    visible_entries =
      get_visible_entries(flat_entries, state.scroll_offset, height - 4)

    # Build tree lines
    tree_lines =
      visible_entries
      |> Enum.with_index(state.scroll_offset)
      |> Enum.map(fn {{entry, level}, global_index} ->
        is_selected = global_index == state.selected_index
        build_tree_line(entry, level, is_selected, state.expanded_dirs, width)
      end)

    # Footer
    footer = build_footer(state, width)

    ([header] ++ tree_lines ++ [footer])
    |> Enum.join("\n")
  end

  defp build_header(path, width) do
    truncated_path = truncate_path(path, width - 4)

    padding =
      String.duplicate(" ", max(0, width - String.length(truncated_path) - 2))

    [
      "┌" <> String.duplicate("─", width - 2) <> "┐",
      "│" <> truncated_path <> padding <> "│",
      "├" <> String.duplicate("─", width - 2) <> "┤"
    ]
    |> Enum.join("\n")
  end

  defp build_tree_line(entry, level, is_selected, expanded_dirs, width) do
    # Indentation
    indent = String.duplicate("  ", level)

    # Selection indicator
    selector =
      case is_selected do
        true -> "▶ "
        false -> "  "
      end

    # Icon
    icon = get_icon(entry, expanded_dirs)

    # Name (truncated if needed)
    max_name_length = width - String.length(indent) - 6
    name = truncate_name(entry.name, max_name_length)

    # Build line
    content = selector <> indent <> icon <> " " <> name
    padding = String.duplicate(" ", max(0, width - String.length(content) - 2))

    "│" <> content <> padding <> "│"
  end

  defp build_footer(state, width) do
    flat_entries = flatten_tree(state.entries, state.expanded_dirs)
    total = length(flat_entries)
    current = state.selected_index + 1

    info = "#{current}/#{total}"
    padding = String.duplicate(" ", max(0, width - String.length(info) - 2))

    [
      "├" <> String.duplicate("─", width - 2) <> "┤",
      "│" <> info <> padding <> "│",
      "└" <> String.duplicate("─", width - 2) <> "┘"
    ]
    |> Enum.join("\n")
  end

  # Tree flattening
  defp flatten_tree(entries, expanded_dirs, level \\ 0) do
    Enum.flat_map(entries, fn entry ->
      current = [{entry, level}]

      children =
        case entry.type == :directory and
               MapSet.member?(expanded_dirs, entry.path) do
          true when is_list(entry.children) ->
            flatten_tree(entry.children, expanded_dirs, level + 1)

          _ ->
            []
        end

      current ++ children
    end)
  end

  # Helpers
  defp get_icon(entry, expanded_dirs) do
    case entry.type do
      :directory ->
        case MapSet.member?(expanded_dirs, entry.path) do
          true -> "▼"
          false -> "▶"
        end

      :regular ->
        case Path.extname(entry.name) do
          ".ex" -> "※"
          ".exs" -> "※"
          ".md" -> "▣"
          ".txt" -> "▤"
          ".json" -> "◈"
          ".toml" -> "◈"
          ".yaml" -> "◈"
          ".yml" -> "◈"
          _ -> "○"
        end

      _ ->
        "?"
    end
  end

  defp truncate_path(path, max_length) do
    case String.length(path) > max_length do
      true -> "..." <> String.slice(path, -(max_length - 3)..-1)
      false -> path
    end
  end

  defp truncate_name(name, max_length) do
    case String.length(name) > max_length do
      true -> String.slice(name, 0, max_length - 3) <> "..."
      false -> name
    end
  end

  defp get_visible_entries(flat_entries, scroll_offset, visible_count) do
    flat_entries
    |> Enum.drop(scroll_offset)
    |> Enum.take(visible_count)
  end

  defp adjust_scroll(state) do
    visible_count = state.panel_height - 4

    cond do
      state.selected_index < state.scroll_offset ->
        %{state | scroll_offset: state.selected_index}

      state.selected_index >= state.scroll_offset + visible_count ->
        %{state | scroll_offset: state.selected_index - visible_count + 1}

      true ->
        state
    end
  end

  defp toggle_hidden(state) do
    show_hidden = not state.config.show_hidden
    config = Map.put(state.config, :show_hidden, show_hidden)
    entries = load_directory(state.current_path, show_hidden)

    new_state = %{state | config: config, entries: entries, selected_index: 0}
    render_browser(new_state)
    {:ok, new_state}
  end

  defp handle_selection(state) do
    flat_entries = flatten_tree(state.entries, state.expanded_dirs)

    case Enum.at(flat_entries, state.selected_index) do
      nil ->
        {:ok, state}

      {_entry, _level} ->
        expand_or_enter(%{state | selected_index: state.selected_index})
    end
  end

  # File operations
  defp open_file(path) do
    Log.info("Opening file: #{path}")
    # Send event to open file in editor
    send(self(), {:open_file, path})
  end

  defp start_filter(state) do
    Log.info("Starting filter mode")
    {:ok, state}
  end

  defp create_file_prompt(state) do
    Log.info("Create file prompt")
    {:ok, state}
  end

  defp delete_file_prompt(state) do
    Log.info("Delete file prompt")
    {:ok, state}
  end

  defp rename_file_prompt(state) do
    Log.info("Rename file prompt")
    {:ok, state}
  end

  # Integration
  defp send_panel(nil, _content, _position), do: :ok

  defp send_panel(pid, content, position) do
    send(pid, {:render_panel, content, position})
  end

  defp clear_panel(nil), do: :ok

  defp clear_panel(pid) do
    send(pid, :clear_panel)
  end

  # BaseManager callbacks
  @impl true
  def handle_manager_cast({:set_emulator, pid}, state) do
    {:noreply, %{state | emulator_pid: pid}}
  end

  @impl true
  def handle_manager_info({:file_changed, path}, state) do
    # Reload if current directory changed
    case Path.dirname(path) == state.current_path do
      true ->
        entries = load_directory(state.current_path, state.config.show_hidden)
        new_state = %{state | entries: entries}
        render_browser(new_state)
        {:noreply, new_state}

      false ->
        {:noreply, state}
    end
  end

  @impl true
  def handle_manager_info(msg, state) do
    Log.debug("Received message: #{inspect(msg)}")
    {:noreply, state}
  end
end
