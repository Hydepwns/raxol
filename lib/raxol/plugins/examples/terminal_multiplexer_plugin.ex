defmodule Raxol.Plugins.Examples.TerminalMultiplexerPlugin do
  @moduledoc """
  Terminal Multiplexer Plugin for Raxol Terminal

  Provides tmux/screen-like terminal multiplexing with panes and windows.
  Demonstrates:
  - Multiple terminal management
  - Pane splitting and navigation
  - Session management
  - Layout persistence
  - Command routing
  """

  use Raxol.Core.Behaviours.BaseManager
  alias Raxol.Core.Runtime.Log
  # Plugin Manifest
  def manifest do
    %{
      name: "terminal-multiplexer",
      version: "1.0.0",
      description: "Terminal multiplexing with panes and windows",
      author: "Raxol Team",
      dependencies: %{
        "raxol-core" => "~> 1.5"
      },
      capabilities: [
        :terminal_management,
        :pane_splitting,
        :session_management,
        :keyboard_input
      ],
      config_schema: %{
        prefix_key: %{type: :string, default: "ctrl+a"},
        default_shell: %{type: :string, default: "/bin/bash"},
        save_layout: %{type: :boolean, default: true},
        status_bar: %{type: :boolean, default: true},
        mouse_support: %{type: :boolean, default: true}
      }
    }
  end

  # State structures
  defmodule Pane do
    @moduledoc """
    Terminal pane within a multiplexer window.

    Represents an individual pane with its process, buffer, cursor, and dimensions.
    """
    defstruct [
      :id,
      :pid,
      :buffer,
      :cursor,
      :title,
      :active,
      :width,
      :height,
      :x,
      :y
    ]
  end

  defmodule Window do
    @moduledoc """
    Window containing multiple panes.

    Manages a collection of panes with layout information and active pane tracking.
    """
    defstruct [
      :id,
      :name,
      :panes,
      :active_pane,
      :layout,
      :index
    ]
  end

  defmodule Session do
    @moduledoc """
    Multiplexer session containing multiple windows.

    Top-level session structure managing windows, configuration, and keybindings.
    """
    defstruct [
      :id,
      :name,
      :windows,
      :active_window,
      :created_at
    ]
  end

  defstruct [
    :config,
    :sessions,
    :active_session,
    :prefix_active,
    :emulator_pid,
    :command_mode,
    :last_command_time
  ]

  # Initialization
  @impl Raxol.Core.Behaviours.BaseManager
  def init_manager(config) do
    Log.info("Initializing with config: #{inspect(config)}")

    # Create default session with one window
    default_session = create_session("main")
    default_window = create_window("shell", config.default_shell)

    session = %{
      default_session
      | windows: [default_window],
        active_window: default_window.id
    }

    state = %__MODULE__{
      config: config,
      sessions: %{session.id => session},
      active_session: session.id,
      prefix_active: false,
      emulator_pid: nil,
      command_mode: false,
      last_command_time: nil
    }

    {:ok, state}
  end

  # Hot-reload support
  def preserve_state(state) do
    %{
      sessions: state.sessions,
      active_session: state.active_session
    }
  end

  def restore_state(preserved_state, new_config) do
    %__MODULE__{
      config: new_config,
      sessions: preserved_state.sessions || %{},
      active_session: preserved_state.active_session,
      prefix_active: false,
      emulator_pid: nil,
      command_mode: false,
      last_command_time: nil
    }
  end

  # Event Handlers
  def handle_event({:keyboard, key}, state)
      when key == state.config.prefix_key do
    activate_prefix(state)
  end

  def handle_event({:keyboard, key}, %{prefix_active: true} = state) do
    handle_prefixed_command(key, state)
  end

  def handle_event({:keyboard, key}, %{command_mode: true} = state) do
    handle_command_mode(key, state)
  end

  def handle_event({:keyboard, key}, state) do
    # Route to active pane
    route_to_active_pane(state, {:input, key})
    {:ok, state}
  end

  def handle_event({:mouse, action, x, y}, state)
      when state.config.mouse_support do
    handle_mouse_event(action, x, y, state)
  end

  def handle_event({:terminal_resize, {width, height}}, state) do
    resize_layout(state, width, height)
  end

  def handle_event(_event, state) do
    {:ok, state}
  end

  # Prefix command handling
  defp activate_prefix(state) do
    # Check for double-tap to send literal prefix
    case check_double_tap(state.last_command_time) do
      true ->
        route_to_active_pane(state, {:input, state.config.prefix_key})
        {:ok, %{state | last_command_time: DateTime.utc_now()}}

      false ->
        {:ok,
         %{state | prefix_active: true, last_command_time: DateTime.utc_now()}}
    end
  end

  defp check_double_tap(nil), do: false

  defp check_double_tap(last_time) do
    DateTime.diff(DateTime.utc_now(), last_time, :millisecond) < 500
  end

  defp handle_prefixed_command(key, state) do
    new_state = %{state | prefix_active: false}

    case key do
      "c" ->
        create_new_window(new_state)

      "n" ->
        next_window(new_state)

      "p" ->
        previous_window(new_state)

      "%" ->
        split_pane_horizontal(new_state)

      "\"" ->
        split_pane_vertical(new_state)

      "o" ->
        next_pane(new_state)

      "x" ->
        close_pane(new_state)

      "z" ->
        zoom_pane(new_state)

      "d" ->
        detach_session(new_state)

      "s" ->
        show_sessions(new_state)

      "w" ->
        show_windows(new_state)

      ":" ->
        enter_command_mode(new_state)

      "?" ->
        show_help(new_state)

      "up" ->
        select_pane(new_state, :up)

      "down" ->
        select_pane(new_state, :down)

      "left" ->
        select_pane(new_state, :left)

      "right" ->
        select_pane(new_state, :right)

      digit when digit in ~w(0 1 2 3 4 5 6 7 8 9) ->
        switch_to_window(new_state, String.to_integer(digit))

      _ ->
        {:ok, new_state}
    end
  end

  # Window management
  defp create_new_window(state) do
    session = get_active_session(state)

    window =
      create_window(
        "shell-#{length(session.windows) + 1}",
        state.config.default_shell
      )

    updated_session = %{
      session
      | windows: session.windows ++ [window],
        active_window: window.id
    }

    new_state = update_session(state, updated_session)
    render_layout(new_state)
    {:ok, new_state}
  end

  defp create_window(name, shell) do
    pane = create_pane(shell)

    %Window{
      id: generate_id(),
      name: name,
      panes: [pane],
      active_pane: pane.id,
      layout: :single,
      index: 0
    }
  end

  defp next_window(state) do
    session = get_active_session(state)
    current_index = find_window_index(session, session.active_window)
    next_index = rem(current_index + 1, length(session.windows))
    next_window = Enum.at(session.windows, next_index)

    updated_session = %{session | active_window: next_window.id}
    new_state = update_session(state, updated_session)
    render_layout(new_state)
    {:ok, new_state}
  end

  defp previous_window(state) do
    session = get_active_session(state)
    current_index = find_window_index(session, session.active_window)

    prev_index =
      rem(current_index - 1 + length(session.windows), length(session.windows))

    prev_window = Enum.at(session.windows, prev_index)

    updated_session = %{session | active_window: prev_window.id}
    new_state = update_session(state, updated_session)
    render_layout(new_state)
    {:ok, new_state}
  end

  defp switch_to_window(state, index) do
    session = get_active_session(state)

    case Enum.at(session.windows, index) do
      nil ->
        {:ok, state}

      window ->
        updated_session = %{session | active_window: window.id}
        new_state = update_session(state, updated_session)
        render_layout(new_state)
        {:ok, new_state}
    end
  end

  # Pane management
  defp split_pane_horizontal(state) do
    split_pane(state, :horizontal)
  end

  defp split_pane_vertical(state) do
    split_pane(state, :vertical)
  end

  defp split_pane(state, direction) do
    session = get_active_session(state)
    window = get_active_window(session)
    active_pane = get_pane(window, window.active_pane)

    # Calculate dimensions for new panes
    {pane1, pane2} = calculate_split(active_pane, direction)

    # Create new pane
    new_pane = create_pane(state.config.default_shell)

    new_pane = %{
      new_pane
      | width: pane2.width,
        height: pane2.height,
        x: pane2.x,
        y: pane2.y
    }

    # Update existing pane
    updated_pane = %{
      active_pane
      | width: pane1.width,
        height: pane1.height,
        x: pane1.x,
        y: pane1.y
    }

    # Update window
    updated_panes = update_pane_list(window.panes, updated_pane)

    updated_window = %{
      window
      | panes: updated_panes ++ [new_pane],
        active_pane: new_pane.id,
        layout: :split
    }

    # Update state
    updated_session = update_window(session, updated_window)
    new_state = update_session(state, updated_session)

    render_layout(new_state)
    {:ok, new_state}
  end

  defp calculate_split(pane, :horizontal) do
    # Split horizontally (side by side)
    new_width = div(pane.width, 2)
    pane1 = %{width: new_width, height: pane.height, x: pane.x, y: pane.y}

    pane2 = %{
      width: pane.width - new_width,
      height: pane.height,
      x: pane.x + new_width,
      y: pane.y
    }

    {pane1, pane2}
  end

  defp calculate_split(pane, :vertical) do
    # Split vertically (top and bottom)
    new_height = div(pane.height, 2)
    pane1 = %{width: pane.width, height: new_height, x: pane.x, y: pane.y}

    pane2 = %{
      width: pane.width,
      height: pane.height - new_height,
      x: pane.x,
      y: pane.y + new_height
    }

    {pane1, pane2}
  end

  defp next_pane(state) do
    session = get_active_session(state)
    window = get_active_window(session)

    current_index =
      Enum.find_index(window.panes, &(&1.id == window.active_pane))

    next_index = rem(current_index + 1, length(window.panes))
    next_pane = Enum.at(window.panes, next_index)

    updated_window = %{window | active_pane: next_pane.id}
    updated_session = update_window(session, updated_window)
    new_state = update_session(state, updated_session)

    render_layout(new_state)
    {:ok, new_state}
  end

  defp select_pane(state, direction) do
    session = get_active_session(state)
    window = get_active_window(session)
    current_pane = get_pane(window, window.active_pane)

    # Find adjacent pane in the specified direction
    target_pane = find_adjacent_pane(window.panes, current_pane, direction)

    case target_pane do
      nil ->
        {:ok, state}

      pane ->
        updated_window = %{window | active_pane: pane.id}
        updated_session = update_window(session, updated_window)
        new_state = update_session(state, updated_session)
        render_layout(new_state)
        {:ok, new_state}
    end
  end

  defp find_adjacent_pane(panes, current, direction) do
    candidates =
      Enum.filter(panes, fn pane ->
        pane.id != current.id and adjacent?(current, pane, direction)
      end)

    # Return closest pane
    Enum.min_by(
      candidates,
      fn pane ->
        distance(current, pane)
      end,
      fn -> nil end
    )
  end

  defp adjacent?(pane1, pane2, :up), do: pane2.y < pane1.y
  defp adjacent?(pane1, pane2, :down), do: pane2.y > pane1.y
  defp adjacent?(pane1, pane2, :left), do: pane2.x < pane1.x
  defp adjacent?(pane1, pane2, :right), do: pane2.x > pane1.x

  defp distance(pane1, pane2) do
    dx = pane1.x + div(pane1.width, 2) - (pane2.x + div(pane2.width, 2))
    dy = pane1.y + div(pane1.height, 2) - (pane2.y + div(pane2.height, 2))
    :math.sqrt(dx * dx + dy * dy)
  end

  defp close_pane(state) do
    session = get_active_session(state)
    window = get_active_window(session)

    case length(window.panes) do
      1 ->
        # Last pane in window, close window
        close_window(state)

      _ ->
        # Remove pane and redistribute space
        remaining_panes =
          Enum.reject(window.panes, &(&1.id == window.active_pane))

        redistributed_panes = redistribute_space(remaining_panes)

        updated_window = %{
          window
          | panes: redistributed_panes,
            active_pane: List.first(redistributed_panes).id
        }

        updated_session = update_window(session, updated_window)
        new_state = update_session(state, updated_session)
        render_layout(new_state)
        {:ok, new_state}
    end
  end

  defp close_window(state) do
    session = get_active_session(state)

    case length(session.windows) do
      1 ->
        # Last window, can't close
        {:ok, state}

      _ ->
        remaining_windows =
          Enum.reject(session.windows, &(&1.id == session.active_window))

        updated_session = %{
          session
          | windows: remaining_windows,
            active_window: List.first(remaining_windows).id
        }

        new_state = update_session(state, updated_session)
        render_layout(new_state)
        {:ok, new_state}
    end
  end

  defp zoom_pane(state) do
    # Toggle pane zoom
    Log.info("Toggling pane zoom")
    {:ok, state}
  end

  # Session management
  defp create_session(name) do
    %Session{
      id: generate_id(),
      name: name,
      windows: [],
      active_window: nil,
      created_at: DateTime.utc_now()
    }
  end

  defp detach_session(state) do
    Log.info("Detaching from session")
    {:ok, state}
  end

  defp show_sessions(state) do
    Log.info("Showing sessions")
    render_session_list(state)
    {:ok, state}
  end

  defp show_windows(state) do
    Log.info("Showing windows")
    render_window_list(state)
    {:ok, state}
  end

  # Command mode
  defp enter_command_mode(state) do
    {:ok, %{state | command_mode: true}}
  end

  defp handle_command_mode("escape", state) do
    {:ok, %{state | command_mode: false}}
  end

  defp handle_command_mode(key, state) do
    # Build command string
    Log.info("Command mode input: #{key}")
    {:ok, state}
  end

  defp show_help(state) do
    help_text = build_help_text()
    display_overlay(state, help_text)
    {:ok, state}
  end

  # Rendering
  defp render_layout(state) do
    session = get_active_session(state)
    window = get_active_window(session)

    # Render each pane
    Enum.each(window.panes, fn pane ->
      is_active = pane.id == window.active_pane
      render_pane(state, pane, is_active)
    end)

    # Render status bar if enabled
    case state.config.status_bar do
      true -> render_status_bar(state)
      false -> :ok
    end
  end

  defp render_pane(state, pane, is_active) do
    border_style =
      case is_active do
        true -> :active
        false -> :inactive
      end

    # Draw pane border
    draw_border(state.emulator_pid, pane, border_style)

    # Render pane content
    send(state.emulator_pid, {:render_pane, pane.id, pane.buffer})
  end

  defp render_status_bar(state) do
    session = get_active_session(state)
    window = get_active_window(session)

    status = build_status_line(session, window, state)
    send(state.emulator_pid, {:render_status_bar, status})
  end

  defp build_status_line(session, window, _state) do
    windows_info =
      session.windows
      |> Enum.with_index()
      |> Enum.map_join(" ", fn {w, i} ->
        prefix =
          case w.id == window.id do
            true -> "*"
            false -> " "
          end

        "#{prefix}#{i}:#{w.name}"
      end)

    "[#{session.name}] #{windows_info}"
  end

  # Helpers
  defp create_pane(shell) do
    # In real implementation, would spawn actual terminal
    %Pane{
      id: generate_id(),
      pid: spawn_terminal(shell),
      buffer: [],
      cursor: {0, 0},
      title: shell,
      active: false,
      width: 80,
      height: 24,
      x: 0,
      y: 0
    }
  end

  defp spawn_terminal(shell) do
    # Placeholder - would spawn actual terminal process
    spawn(fn ->
      Log.info("Terminal spawned: #{shell}")
      Process.sleep(:infinity)
    end)
  end

  defp generate_id do
    :crypto.strong_rand_bytes(8)
    |> Base.encode16(case: :lower)
  end

  defp get_active_session(state) do
    Map.get(state.sessions, state.active_session)
  end

  defp get_active_window(session) do
    Enum.find(session.windows, &(&1.id == session.active_window))
  end

  defp get_pane(window, pane_id) do
    Enum.find(window.panes, &(&1.id == pane_id))
  end

  defp update_session(state, session) do
    %{state | sessions: Map.put(state.sessions, session.id, session)}
  end

  defp update_window(session, window) do
    windows =
      Enum.map(session.windows, fn w ->
        case w.id == window.id do
          true -> window
          false -> w
        end
      end)

    %{session | windows: windows}
  end

  defp update_pane_list(panes, updated_pane) do
    Enum.map(panes, fn p ->
      case p.id == updated_pane.id do
        true -> updated_pane
        false -> p
      end
    end)
  end

  defp find_window_index(session, window_id) do
    Enum.find_index(session.windows, &(&1.id == window_id)) || 0
  end

  defp redistribute_space(panes) do
    # Simple redistribution - would be more complex in real implementation
    total_width = 80
    total_height = 24
    pane_count = length(panes)

    width_per_pane = div(total_width, pane_count)

    panes
    |> Enum.with_index()
    |> Enum.map(fn {pane, index} ->
      %{
        pane
        | x: index * width_per_pane,
          y: 0,
          width: width_per_pane,
          height: total_height
      }
    end)
  end

  defp resize_layout(state, width, height) do
    Log.info("Resizing layout to #{width}x#{height}")
    {:ok, state}
  end

  defp route_to_active_pane(state, message) do
    session = get_active_session(state)
    window = get_active_window(session)
    pane = get_pane(window, window.active_pane)

    send(pane.pid, message)
  end

  defp handle_mouse_event(action, x, y, state) do
    Log.info("Mouse event: #{action} at (#{x}, #{y})")
    {:ok, state}
  end

  defp render_session_list(state) do
    sessions = Map.values(state.sessions)
    # Render session selection UI
    Log.info("Sessions: #{inspect(sessions)}")
  end

  defp render_window_list(state) do
    session = get_active_session(state)
    # Render window selection UI
    Log.info("Windows: #{inspect(session.windows)}")
  end

  defp display_overlay(state, content) do
    send(state.emulator_pid, {:display_overlay, content})
  end

  defp draw_border(nil, _pane, _style), do: :ok

  defp draw_border(pid, pane, style) do
    send(pid, {:draw_border, pane, style})
  end

  defp build_help_text do
    """
    Terminal Multiplexer Commands
    =============================

    Window Management:
      c - Create new window
      n - Next window
      p - Previous window
      0-9 - Switch to window by index
      x - Close current pane/window

    Pane Management:
      % - Split horizontally
      " - Split vertically
      o - Next pane
      ↑↓←→ - Navigate panes
      z - Zoom/unzoom pane

    Sessions:
      d - Detach session
      s - Show sessions
      w - Show windows

    Other:
      : - Command mode
      ? - Show this help
    """
  end

  # BaseManager callbacks
  @impl Raxol.Core.Behaviours.BaseManager
  def handle_manager_cast({:set_emulator, pid}, state) do
    {:noreply, %{state | emulator_pid: pid}}
  end

  @impl Raxol.Core.Behaviours.BaseManager
  def handle_manager_info(msg, state) do
    Log.debug("Received message: #{inspect(msg)}")
    {:noreply, state}
  end
end
