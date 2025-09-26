defmodule Raxol.Plugins.Examples.CommandPalettePlugin do
  @moduledoc """
  Command Palette Plugin for Raxol Terminal

  Provides a VS Code-style command palette for quick command execution.
  Demonstrates:
  - Plugin lifecycle management
  - Hot-reload support with state preservation
  - Event handling and keyboard shortcuts
  - UI integration
  - Dependency management
  """

  use GenServer
  require Logger

  # Plugin Manifest
  def manifest do
    %{
      name: "command-palette",
      version: "1.0.0",
      description: "Command palette for quick command execution",
      author: "Raxol Team",
      dependencies: %{
        "raxol-core" => "~> 1.5",
        "fuzzy-search" => "~> 0.2"
      },
      capabilities: [
        :ui_overlay,
        :keyboard_input,
        :command_execution
      ],
      config_schema: %{
        hotkey: %{type: :string, default: "ctrl+shift+p"},
        max_results: %{type: :integer, default: 10},
        theme: %{type: :string, default: "dark"}
      }
    }
  end

  # Plugin API
  defstruct [
    :config,
    :state,
    :commands,
    :search_results,
    :selected_index,
    :search_query,
    :is_open,
    :emulator_pid,
    :hot_reload_state
  ]

  # Initialization
  def init(config) do
    Logger.info("[CommandPalette] Initializing with config: #{inspect(config)}")

    state = %__MODULE__{
      config: config,
      state: :initialized,
      commands: load_commands(),
      search_results: [],
      selected_index: 0,
      search_query: "",
      is_open: false,
      emulator_pid: nil,
      hot_reload_state: nil
    }

    # Register keyboard shortcut
    register_hotkey(config.hotkey || "ctrl+shift+p")

    {:ok, state}
  end

  # Hot-reload support
  def preserve_state(state) do
    # Preserve critical state during hot-reload
    %{
      search_query: state.search_query,
      selected_index: state.selected_index,
      is_open: state.is_open,
      commands: state.commands,
      emulator_pid: state.emulator_pid
    }
  end

  def restore_state(preserved_state, new_config) do
    # Restore state after hot-reload
    %__MODULE__{
      config: new_config,
      state: :initialized,
      commands: preserved_state.commands || load_commands(),
      search_results: [],
      selected_index: preserved_state.selected_index || 0,
      search_query: preserved_state.search_query || "",
      is_open: preserved_state.is_open || false,
      emulator_pid: preserved_state.emulator_pid,
      hot_reload_state: preserved_state
    }
  end

  # Event Handlers
  def handle_event({:keyboard, "ctrl+shift+p"}, state) do
    toggle_palette(state)
  end

  def handle_event({:keyboard, "escape"}, %{is_open: true} = state) do
    close_palette(state)
  end

  def handle_event({:keyboard, "enter"}, %{is_open: true} = state) do
    execute_selected_command(state)
  end

  def handle_event({:keyboard, "up"}, %{is_open: true} = state) do
    move_selection(state, :up)
  end

  def handle_event({:keyboard, "down"}, %{is_open: true} = state) do
    move_selection(state, :down)
  end

  def handle_event({:keyboard, key}, %{is_open: true} = state) when byte_size(key) == 1 do
    update_search(state, state.search_query <> key)
  end

  def handle_event({:keyboard, "backspace"}, %{is_open: true} = state) do
    query = String.slice(state.search_query, 0..-2//1) || ""
    update_search(state, query)
  end

  def handle_event(_event, state) do
    {:ok, state}
  end

  # Command Management
  defp load_commands do
    [
      %{
        id: "terminal.clear",
        label: "Clear Terminal",
        description: "Clear the terminal screen",
        action: fn -> clear_terminal() end,
        category: "Terminal"
      },
      %{
        id: "terminal.split",
        label: "Split Terminal",
        description: "Split terminal horizontally",
        action: fn -> split_terminal(:horizontal) end,
        category: "Terminal"
      },
      %{
        id: "file.open",
        label: "Open File",
        description: "Open a file in the terminal",
        action: fn -> open_file_dialog() end,
        category: "File"
      },
      %{
        id: "theme.change",
        label: "Change Theme",
        description: "Change the terminal theme",
        action: fn -> change_theme_dialog() end,
        category: "Appearance"
      },
      %{
        id: "plugin.reload",
        label: "Reload Plugins",
        description: "Hot-reload all plugins",
        action: fn -> reload_all_plugins() end,
        category: "Plugin"
      },
      %{
        id: "help.docs",
        label: "Open Documentation",
        description: "Open Raxol documentation",
        action: fn -> open_documentation() end,
        category: "Help"
      }
    ]
  end

  defp toggle_palette(state) do
    case state.is_open do
      true -> close_palette(state)
      false -> open_palette(state)
    end
  end

  defp open_palette(state) do
    new_state = %{state |
      is_open: true,
      search_query: "",
      search_results: state.commands,
      selected_index: 0
    }

    render_palette(new_state)
    {:ok, new_state}
  end

  defp close_palette(state) do
    new_state = %{state |
      is_open: false,
      search_query: "",
      search_results: [],
      selected_index: 0
    }

    clear_overlay(state.emulator_pid)
    {:ok, new_state}
  end

  defp update_search(state, query) do
    # Fuzzy search through commands
    results = fuzzy_search(state.commands, query)

    new_state = %{state |
      search_query: query,
      search_results: results,
      selected_index: 0
    }

    render_palette(new_state)
    {:ok, new_state}
  end

  defp fuzzy_search(commands, "") do
    commands
  end

  defp fuzzy_search(commands, query) do
    query_lower = String.downcase(query)

    commands
    |> Enum.filter(fn cmd ->
      String.contains?(String.downcase(cmd.label), query_lower) or
      String.contains?(String.downcase(cmd.description), query_lower) or
      String.contains?(String.downcase(cmd.category), query_lower)
    end)
    |> Enum.sort_by(fn cmd ->
      # Score based on match position (earlier = better)
      label_pos = string_position(String.downcase(cmd.label), query_lower)
      desc_pos = string_position(String.downcase(cmd.description), query_lower)
      min(label_pos, desc_pos)
    end)
  end

  defp string_position(haystack, needle) do
    case :binary.match(haystack, needle) do
      {pos, _} -> pos
      :nomatch -> 999999
    end
  end

  defp move_selection(state, :up) do
    new_index = max(0, state.selected_index - 1)
    new_state = %{state | selected_index: new_index}
    render_palette(new_state)
    {:ok, new_state}
  end

  defp move_selection(state, :down) do
    max_index = length(state.search_results) - 1
    new_index = min(max_index, state.selected_index + 1)
    new_state = %{state | selected_index: new_index}
    render_palette(new_state)
    {:ok, new_state}
  end

  defp execute_selected_command(state) do
    case Enum.at(state.search_results, state.selected_index) do
      nil ->
        {:ok, state}

      command ->
        Logger.info("[CommandPalette] Executing command: #{command.id}")

        # Execute command action
        spawn(fn -> command.action.() end)

        # Close palette after execution
        close_palette(state)
    end
  end

  # UI Rendering
  defp render_palette(state) do
    # Create overlay UI for command palette
    overlay_content = build_palette_ui(state)

    # Send to emulator for rendering
    send_overlay(state.emulator_pid, overlay_content)
  end

  defp build_palette_ui(state) do
    width = 60
    max_results = state.config.max_results || 10

    header = build_header(state.search_query, width)
    results = build_results(state.search_results, state.selected_index, max_results, width)
    footer = build_footer(width)

    [header | results] ++ [footer]
    |> Enum.join("\n")
  end

  defp build_header(query, width) do
    search_text = "> #{query}_"
    padding = String.duplicate(" ", max(0, width - String.length(search_text)))

    [
      "┌" <> String.duplicate("─", width - 2) <> "┐",
      "│ Command Palette" <> String.duplicate(" ", width - 18) <> "│",
      "├" <> String.duplicate("─", width - 2) <> "┤",
      "│" <> search_text <> padding <> "│",
      "├" <> String.duplicate("─", width - 2) <> "┤"
    ]
    |> Enum.join("\n")
  end

  defp build_results(results, selected_index, max_results, width) do
    results
    |> Enum.take(max_results)
    |> Enum.with_index()
    |> Enum.map(fn {cmd, index} ->
      is_selected = index == selected_index
      build_result_line(cmd, is_selected, width)
    end)
  end

  defp build_result_line(command, is_selected, width) do
    prefix = if is_selected, do: "▶ ", else: "  "
    category = "[#{command.category}]"
    label = command.label

    # Build the line with proper spacing
    content = "#{prefix}#{category} #{label}"
    padding = String.duplicate(" ", max(0, width - String.length(content) - 2))

    "│" <> content <> padding <> "│"
  end

  defp build_footer(width) do
    "└" <> String.duplicate("─", width - 2) <> "┘"
  end

  # Integration helpers
  defp register_hotkey(_key_combo) do
    # Register with the terminal's keyboard event system
    :ok
  end

  defp send_overlay(nil, _content), do: :ok
  defp send_overlay(emulator_pid, content) do
    # Send overlay content to emulator
    send(emulator_pid, {:render_overlay, content})
  end

  defp clear_overlay(nil), do: :ok
  defp clear_overlay(emulator_pid) do
    send(emulator_pid, :clear_overlay)
  end

  # Command actions
  defp clear_terminal do
    Logger.info("[CommandPalette] Clearing terminal")
    # Implementation would clear the terminal
  end

  defp split_terminal(direction) do
    Logger.info("[CommandPalette] Splitting terminal #{direction}")
    # Implementation would split the terminal
  end

  defp open_file_dialog do
    Logger.info("[CommandPalette] Opening file dialog")
    # Implementation would show file picker
  end

  defp change_theme_dialog do
    Logger.info("[CommandPalette] Opening theme selector")
    # Implementation would show theme picker
  end

  defp reload_all_plugins do
    Logger.info("[CommandPalette] Reloading all plugins")
    # Trigger hot-reload for all plugins using available method
    case Raxol.Plugins.Manager.list_plugins() do
      {:ok, plugins} ->
        Enum.each(plugins, fn plugin_id ->
          Raxol.Plugins.HotReloadManager.reload_plugin(plugin_id)
        end)
      _ ->
        Logger.warning("[CommandPalette] Could not list plugins for reload")
    end
  end

  defp open_documentation do
    Logger.info("[CommandPalette] Opening documentation")
    # Open browser with docs
    System.cmd("open", ["https://docs.raxol.io"])
  end

  # GenServer callbacks
  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  def handle_call({:execute_command, command_id}, _from, state) do
    command = Enum.find(state.commands, &(&1.id == command_id))

    case command do
      nil ->
        {:reply, {:error, :command_not_found}, state}
      cmd ->
        spawn(fn -> cmd.action.() end)
        {:reply, :ok, state}
    end
  end

  def handle_cast({:set_emulator, pid}, state) do
    {:noreply, %{state | emulator_pid: pid}}
  end

  def handle_cast({:add_command, command}, state) do
    new_commands = [command | state.commands]
    {:noreply, %{state | commands: new_commands}}
  end

  def handle_info(msg, state) do
    Logger.debug("[CommandPalette] Received message: #{inspect(msg)}")
    {:noreply, state}
  end
end