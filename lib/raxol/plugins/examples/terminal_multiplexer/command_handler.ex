defmodule Raxol.Plugins.Examples.TerminalMultiplexer.CommandHandler do
  @moduledoc """
  Command routing for the TerminalMultiplexerPlugin.

  Handles prefix-key commands, command mode, and double-tap detection.
  """

  alias Raxol.Core.Runtime.Log
  alias Raxol.Plugins.Examples.TerminalMultiplexer.{PaneManager, WindowManager}

  @compile {:no_warn_undefined,
            Raxol.Plugins.Examples.TerminalMultiplexer.PaneManager}
  @compile {:no_warn_undefined,
            Raxol.Plugins.Examples.TerminalMultiplexer.WindowManager}

  @doc "Activates prefix mode or sends literal prefix on double-tap."
  def activate_prefix(state) do
    case check_double_tap(state.last_command_time) do
      true ->
        route_to_active_pane(state, {:input, state.config.prefix_key})
        {:ok, %{state | last_command_time: DateTime.utc_now()}}

      false ->
        {:ok,
         %{state | prefix_active: true, last_command_time: DateTime.utc_now()}}
    end
  end

  @doc "Handles a key press when prefix mode is active."
  def handle_prefixed_command(key, state) do
    new_state = %{state | prefix_active: false}

    dispatch_prefixed_window(key, new_state) ||
      dispatch_prefixed_pane(key, new_state) ||
      dispatch_prefixed_misc(key, new_state) ||
      {:ok, new_state}
  end

  defp dispatch_prefixed_window(key, state) do
    case key do
      "c" ->
        WindowManager.create_new_window(state)

      "n" ->
        WindowManager.next_window(state)

      "p" ->
        WindowManager.previous_window(state)

      "d" ->
        WindowManager.detach_session(state)

      "s" ->
        WindowManager.show_sessions(state)

      "w" ->
        WindowManager.show_windows(state)

      digit when digit in ~w(0 1 2 3 4 5 6 7 8 9) ->
        WindowManager.switch_to_window(state, String.to_integer(digit))

      _ ->
        nil
    end
  end

  defp dispatch_prefixed_pane(key, state) do
    dispatch_pane_action(key, state) || dispatch_pane_navigation(key, state)
  end

  defp dispatch_pane_action(key, state) do
    case key do
      "%" -> PaneManager.split_horizontal(state)
      "\"" -> PaneManager.split_vertical(state)
      "o" -> PaneManager.next_pane(state)
      "x" -> PaneManager.close_pane(state)
      "z" -> PaneManager.zoom_pane(state)
      _ -> nil
    end
  end

  defp dispatch_pane_navigation(key, state) do
    case key do
      "up" -> PaneManager.select_pane(state, :up)
      "down" -> PaneManager.select_pane(state, :down)
      "left" -> PaneManager.select_pane(state, :left)
      "right" -> PaneManager.select_pane(state, :right)
      _ -> nil
    end
  end

  defp dispatch_prefixed_misc(key, state) do
    case key do
      ":" -> enter_command_mode(state)
      "?" -> show_help(state)
      _ -> nil
    end
  end

  @doc "Handles a key press when command mode is active."
  def handle_command_mode("escape", state) do
    {:ok, %{state | command_mode: false}}
  end

  def handle_command_mode(key, state) do
    Log.info("Command mode input: #{key}")
    {:ok, state}
  end

  @doc "Routes input to the active pane."
  def route_to_active_pane(state, message) do
    session = Map.get(state.sessions, state.active_session)
    window = Enum.find(session.windows, &(&1.id == session.active_window))
    pane = Enum.find(window.panes, &(&1.id == window.active_pane))
    send(pane.pid, message)
  end

  @doc "Returns the help text string."
  def build_help_text do
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
      \u2191\u2193\u2190\u2192 - Navigate panes
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

  # --- Private helpers ---

  defp check_double_tap(nil), do: false

  defp check_double_tap(last_time) do
    DateTime.diff(DateTime.utc_now(), last_time, :millisecond) < 500
  end

  defp enter_command_mode(state) do
    {:ok, %{state | command_mode: true}}
  end

  defp show_help(state) do
    send(state.emulator_pid, {:display_overlay, build_help_text()})
    {:ok, state}
  end
end
