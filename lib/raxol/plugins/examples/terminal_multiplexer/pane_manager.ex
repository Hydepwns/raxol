defmodule Raxol.Plugins.Examples.TerminalMultiplexer.PaneManager do
  @moduledoc """
  Pane operations for the TerminalMultiplexerPlugin.

  Handles pane splitting, navigation, closing, and space redistribution.
  """

  alias Raxol.Core.Runtime.Log
  alias Raxol.Plugins.Examples.TerminalMultiplexerPlugin.Pane

  @compile {:no_warn_undefined,
            Raxol.Plugins.Examples.TerminalMultiplexerPlugin.Pane}

  @doc "Split the active pane horizontally (side by side)."
  def split_horizontal(state), do: split_pane(state, :horizontal)

  @doc "Split the active pane vertically (top and bottom)."
  def split_vertical(state), do: split_pane(state, :vertical)

  @doc "Cycles to the next pane in the window."
  def next_pane(state) do
    session = get_active_session(state)
    window = get_active_window(session)

    current_index =
      Enum.find_index(window.panes, &(&1.id == window.active_pane))

    next_index = rem(current_index + 1, length(window.panes))
    next_p = Enum.at(window.panes, next_index)

    updated_window = %{window | active_pane: next_p.id}
    updated_session = update_window(session, updated_window)
    new_state = update_session(state, updated_session)
    render_layout(new_state)
    {:ok, new_state}
  end

  @doc "Selects the pane adjacent in the given direction."
  def select_pane(state, direction) do
    session = get_active_session(state)
    window = get_active_window(session)
    current_pane = get_pane(window, window.active_pane)

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

  @doc "Closes the active pane (or window if it's the last pane)."
  def close_pane(state) do
    session = get_active_session(state)
    window = get_active_window(session)

    case length(window.panes) do
      1 ->
        close_window(state)

      _ ->
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

  @doc "Toggles pane zoom."
  def zoom_pane(state) do
    Log.info("Toggling pane zoom")
    {:ok, state}
  end

  @doc "Creates a new Pane struct."
  def create_pane(shell) do
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

  # --- Private helpers ---

  defp split_pane(state, direction) do
    session = get_active_session(state)
    window = get_active_window(session)
    active_pane = get_pane(window, window.active_pane)

    {pane1, pane2} = calculate_split(active_pane, direction)

    new_pane = create_pane(state.config.default_shell)

    new_pane = %{
      new_pane
      | width: pane2.width,
        height: pane2.height,
        x: pane2.x,
        y: pane2.y
    }

    updated_pane = %{
      active_pane
      | width: pane1.width,
        height: pane1.height,
        x: pane1.x,
        y: pane1.y
    }

    updated_panes = update_pane_list(window.panes, updated_pane)

    updated_window = %{
      window
      # credo:disable-for-next-line Credo.Check.Refactor.AppendSingleItem
      | panes: updated_panes ++ [new_pane],
        active_pane: new_pane.id,
        layout: :split
    }

    updated_session = update_window(session, updated_window)
    new_state = update_session(state, updated_session)
    render_layout(new_state)
    {:ok, new_state}
  end

  defp close_window(state) do
    session = get_active_session(state)

    case length(session.windows) do
      1 ->
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

  defp calculate_split(pane, :horizontal) do
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

  defp find_adjacent_pane(panes, current, direction) do
    candidates =
      Enum.filter(
        panes,
        &(&1.id != current.id and adjacent?(current, &1, direction))
      )

    Enum.min_by(candidates, &distance(current, &1), fn -> nil end)
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

  defp redistribute_space(panes) do
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

  defp update_pane_list(panes, updated_pane) do
    Enum.map(panes, fn p ->
      if p.id == updated_pane.id, do: updated_pane, else: p
    end)
  end

  defp spawn_terminal(shell) do
    spawn(fn ->
      Log.info("Terminal spawned: #{shell}")
      Process.sleep(:infinity)
    end)
  end

  defp generate_id do
    :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)
  end

  defp get_active_session(state),
    do: Map.get(state.sessions, state.active_session)

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
        if w.id == window.id, do: window, else: w
      end)

    %{session | windows: windows}
  end

  defp render_layout(_state), do: :ok
end
