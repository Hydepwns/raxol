defmodule Raxol.Plugins.Examples.TerminalMultiplexer.Renderer do
  @moduledoc """
  Layout rendering for the TerminalMultiplexerPlugin.

  Handles pane borders, status bar, and list overlays.
  """

  alias Raxol.Core.Runtime.Log

  @doc "Renders the current layout to the emulator."
  def render_layout(state) do
    session = Map.get(state.sessions, state.active_session)
    window = Enum.find(session.windows, &(&1.id == session.active_window))

    Enum.each(window.panes, fn pane ->
      is_active = pane.id == window.active_pane
      render_pane(state, pane, is_active)
    end)

    case state.config.status_bar do
      true -> render_status_bar(state)
      false -> :ok
    end
  end

  @doc "Renders a session list overlay."
  def render_session_list(state) do
    sessions = Map.values(state.sessions)
    Log.info("Sessions: #{inspect(sessions)}")
  end

  @doc "Renders a window list overlay."
  def render_window_list(state) do
    session = Map.get(state.sessions, state.active_session)
    Log.info("Windows: #{inspect(session.windows)}")
  end

  # --- Private helpers ---

  defp render_pane(state, pane, is_active) do
    border_style = if is_active, do: :active, else: :inactive
    draw_border(state.emulator_pid, pane, border_style)
    send(state.emulator_pid, {:render_pane, pane.id, pane.buffer})
  end

  defp render_status_bar(state) do
    session = Map.get(state.sessions, state.active_session)
    window = Enum.find(session.windows, &(&1.id == session.active_window))
    status = build_status_line(session, window)
    send(state.emulator_pid, {:render_status_bar, status})
  end

  defp build_status_line(session, window) do
    windows_info =
      session.windows
      |> Enum.with_index()
      |> Enum.map_join(" ", fn {w, i} ->
        prefix = if w.id == window.id, do: "*", else: " "
        "#{prefix}#{i}:#{w.name}"
      end)

    "[#{session.name}] #{windows_info}"
  end

  defp draw_border(nil, _pane, _style), do: :ok

  defp draw_border(pid, pane, style) do
    send(pid, {:draw_border, pane, style})
  end
end
