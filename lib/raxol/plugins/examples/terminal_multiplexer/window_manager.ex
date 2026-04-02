defmodule Raxol.Plugins.Examples.TerminalMultiplexer.WindowManager do
  @moduledoc """
  Window operations for the TerminalMultiplexerPlugin.

  Handles window creation, navigation, and session management.
  """

  alias Raxol.Core.Runtime.Log
  alias Raxol.Plugins.Examples.TerminalMultiplexer.PaneManager
  alias Raxol.Plugins.Examples.TerminalMultiplexerPlugin.{Session, Window}

  @compile {:no_warn_undefined,
            Raxol.Plugins.Examples.TerminalMultiplexer.PaneManager}
  @compile {:no_warn_undefined,
            Raxol.Plugins.Examples.TerminalMultiplexerPlugin.Session}
  @compile {:no_warn_undefined,
            Raxol.Plugins.Examples.TerminalMultiplexerPlugin.Window}

  @doc "Creates a new window and adds it to the active session."
  def create_new_window(state) do
    session = get_active_session(state)

    window =
      create_window(
        "shell-#{length(session.windows) + 1}",
        state.config.default_shell
      )

    updated_session = %{
      session
      # credo:disable-for-next-line Credo.Check.Refactor.AppendSingleItem
      | windows: session.windows ++ [window],
        active_window: window.id
    }

    new_state = update_session(state, updated_session)
    {:ok, new_state}
  end

  @doc "Switches to the next window in the active session."
  def next_window(state) do
    session = get_active_session(state)
    current_index = find_window_index(session, session.active_window)
    next_index = rem(current_index + 1, length(session.windows))
    next_w = Enum.at(session.windows, next_index)

    updated_session = %{session | active_window: next_w.id}
    new_state = update_session(state, updated_session)
    {:ok, new_state}
  end

  @doc "Switches to the previous window in the active session."
  def previous_window(state) do
    session = get_active_session(state)
    current_index = find_window_index(session, session.active_window)

    prev_index =
      rem(current_index - 1 + length(session.windows), length(session.windows))

    prev_w = Enum.at(session.windows, prev_index)

    updated_session = %{session | active_window: prev_w.id}
    new_state = update_session(state, updated_session)
    {:ok, new_state}
  end

  @doc "Switches to the window at the given index."
  def switch_to_window(state, index) do
    session = get_active_session(state)

    case Enum.at(session.windows, index) do
      nil ->
        {:ok, state}

      window ->
        updated_session = %{session | active_window: window.id}
        new_state = update_session(state, updated_session)
        {:ok, new_state}
    end
  end

  @doc "Detaches from the current session."
  def detach_session(state) do
    Log.info("Detaching from session")
    {:ok, state}
  end

  @doc "Shows the session list overlay."
  def show_sessions(state) do
    Log.info("Showing sessions")
    sessions = Map.values(state.sessions)
    Log.info("Sessions: #{inspect(sessions)}")
    {:ok, state}
  end

  @doc "Shows the window list overlay."
  def show_windows(state) do
    Log.info("Showing windows")
    session = get_active_session(state)
    Log.info("Windows: #{inspect(session.windows)}")
    {:ok, state}
  end

  @doc "Creates a new Session struct."
  def create_session(name) do
    %Session{
      id: generate_id(),
      name: name,
      windows: [],
      active_window: nil,
      created_at: DateTime.utc_now()
    }
  end

  @doc "Creates a new Window struct with a single pane."
  def create_window(name, shell) do
    pane = PaneManager.create_pane(shell)

    %Window{
      id: generate_id(),
      name: name,
      panes: [pane],
      active_pane: pane.id,
      layout: :single,
      index: 0
    }
  end

  # --- Private helpers ---

  defp find_window_index(session, window_id) do
    Enum.find_index(session.windows, &(&1.id == window_id)) || 0
  end

  defp generate_id do
    :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)
  end

  defp get_active_session(state),
    do: Map.get(state.sessions, state.active_session)

  defp update_session(state, session) do
    %{state | sessions: Map.put(state.sessions, session.id, session)}
  end
end
