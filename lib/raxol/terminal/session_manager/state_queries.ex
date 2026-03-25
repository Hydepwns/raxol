defmodule Raxol.Terminal.SessionManager.StateQueries do
  @moduledoc """
  State query helpers for SessionManager: finding panes/windows and building summaries.
  """

  @doc """
  Finds a pane by session_id, window_id, and pane_id within the manager state.
  Returns {:ok, session, window, pane} or {:error, reason}.
  """
  def find_pane(state, session_id, window_id, pane_id) do
    with {:ok, session} <- Map.fetch(state.sessions, session_id),
         {:ok, window} <- find_window_in_session(session, window_id),
         {:ok, pane} <- find_pane_in_window(window, pane_id) do
      {:ok, session, window, pane}
    else
      :error -> {:error, :not_found}
    end
  end

  @doc """
  Finds a window by id within a session.
  """
  def find_window_in_session(session, window_id) do
    case Enum.find(session.windows, &(&1.id == window_id)) do
      nil -> :error
      window -> {:ok, window}
    end
  end

  @doc """
  Finds a pane by id within a window.
  """
  def find_pane_in_window(window, pane_id) do
    case Enum.find(window.panes, &(&1.id == pane_id)) do
      nil -> :error
      pane -> {:ok, pane}
    end
  end

  @doc """
  Updates a window within a session in the manager state.
  """
  def update_window_in_session(state, session_id, window_id, updated_window) do
    session = Map.get(state.sessions, session_id)

    updated_windows =
      Enum.map(session.windows, fn window ->
        if window.id == window_id, do: updated_window, else: window
      end)

    updated_session = %{session | windows: updated_windows}
    updated_sessions = Map.put(state.sessions, session_id, updated_session)
    %{state | sessions: updated_sessions}
  end

  @doc """
  Builds a summary map for a session.
  """
  def session_summary(session) do
    %{
      id: session.id,
      name: session.name,
      status: session.status,
      windows: length(session.windows),
      clients: length(session.clients),
      created_at: session.created_at,
      last_activity: session.last_activity
    }
  end
end
