defmodule Raxol.UI.Rendering.Renderer do
  @moduledoc """
  GenServer responsible for managing rendering state and applying animation settings.
  Receives commands from the rendering pipeline and coordinates rendering actions.
  """

  import Raxol.Guards
  use GenServer
  require Raxol.Core.Runtime.Log

  # Public API

  @doc """
  Starts the rendering process.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, %{}, opts)
  end

  @doc """
  Sets animation settings for the renderer.
  """
  def set_animation_settings(settings) when is_map(settings) do
    GenServer.cast(__MODULE__, {:set_animation_settings, settings})
  end

  @doc """
  Triggers a render with the current state.
  """
  def render(data \\ nil) do
    GenServer.cast(__MODULE__, {:render, data})
  end

  @doc """
  Sets a test process PID to receive render messages (for test visibility).
  No-op in production.
  """
  def set_test_pid(pid) when is_pid(pid) do
    GenServer.cast(__MODULE__, {:set_test_pid, pid})
  end

  @doc """
  Applies a diff to the renderer. For now, only full replacement is supported; granular diffs are logged and trigger a full render.
  """
  def apply_diff(:no_change, _new_tree), do: :ok
  def apply_diff({:replace, new_tree}, _new_tree), do: render(new_tree)

  def apply_diff({:update, path, changes} = diff, new_tree) do
    GenServer.cast(__MODULE__, {:apply_diff, diff, new_tree})
  end

  # Recursively applies a diff to a tree, returning the updated tree
  defp apply_diff_to_tree(tree, {:update, [], changes}) do
    # At root, apply all child diffs
    apply_child_diffs(tree, changes)
  end

  defp apply_diff_to_tree(tree, {:update, [idx | rest], changes}) do
    # Descend to the child at idx
    %{
      tree
      | children:
          update_nth(tree.children, idx, fn child ->
            apply_diff_to_tree(child, {:update, rest, changes})
          end)
    }
  end

  defp apply_diff_to_tree(_tree, {:replace, new_subtree}), do: new_subtree
  defp apply_diff_to_tree(tree, :no_change), do: tree

  # Applies a list of {idx, diff} changes to the children list
  defp apply_child_diffs(tree, changes) do
    updated_children =
      Enum.reduce(changes, tree.children, fn {idx, diff}, acc ->
        List.update_at(acc, idx, fn child -> apply_diff_to_tree(child, diff) end)
      end)

    %{tree | children: updated_children}
  end

  # Utility to update the nth element of a list with a function
  defp update_nth(list, idx, fun) do
    List.update_at(list, idx, fun)
  end

  # Simulate partial rendering (stub for backend integration)
  defp do_partial_render(_path, updated_subtree, _updated_tree, state) do
    ops = ui_tree_to_terminal_ops_with_lines(updated_subtree)
    emulator = get_emulator(state)
    buffer = Raxol.Terminal.Emulator.get_active_buffer(emulator)

    updated_buffer =
      Enum.reduce(ops, buffer, fn
        {:draw_text, y, text}, buf ->
          x = 0
          Raxol.Terminal.Buffer.Operations.write_string(buf, x, y, text)

        _, buf ->
          buf
      end)

    updated_emulator =
      Raxol.Terminal.Emulator.update_active_buffer(emulator, updated_buffer)

    new_state = put_emulator(state, updated_emulator)
    require Raxol.Core.Runtime.Log

    Raxol.Core.Runtime.Log.info(
      "Partial render ops (line-based): #{inspect(ops)} (buffer updated)"
    )

    {new_state, :ok}
  end

  defp get_emulator(state), do: Map.get(state, :emulator)
  defp put_emulator(state, emulator), do: Map.put(state, :emulator, emulator)

  # Depth-first traversal to collect label ops with line numbers
  defp ui_tree_to_terminal_ops_with_lines(tree) do
    ui_tree_to_terminal_ops_with_lines(tree, 0) |> elem(0)
  end

  defp ui_tree_to_terminal_ops_with_lines(
         %{type: :label, attrs: %{text: text}},
         line
       ) do
    {[{:draw_text, line, text}], line + 1}
  end

  defp ui_tree_to_terminal_ops_with_lines(
         %{type: :view, children: children},
         line
       ) do
    Enum.reduce(children, {[], line}, fn child, {acc, l} ->
      {ops, next_line} = ui_tree_to_terminal_ops_with_lines(child, l)
      {acc ++ ops, next_line}
    end)
  end

  defp ui_tree_to_terminal_ops_with_lines(_other, line), do: {[], line}

  # GenServer Callbacks

  @impl true
  def init(_init_arg) do
    emulator = Raxol.Terminal.Emulator.new(80, 24, [])

    {:ok,
     %{
       animation_settings: nil,
       last_render: nil,
       test_pid: nil,
       emulator: emulator
     }}
  end

  @impl true
  def handle_cast({:set_animation_settings, settings}, state) do
    {:noreply, %{state | animation_settings: settings}}
  end

  @impl true
  def handle_cast({:render, data}, state) do
    # Update the buffer for the full tree render
    {new_state, _} = do_partial_render([], data, data, state)
    if state.test_pid, do: send(state.test_pid, {:renderer_rendered, data})
    require Raxol.Core.Runtime.Log

    Raxol.Core.Runtime.Log.info(
      "Renderer received render: #{inspect(data)} (buffer updated)"
    )

    {:noreply, %{new_state | last_render: data}}
  end

  @impl true
  def handle_cast({:set_test_pid, pid}, state) do
    {:noreply, %{state | test_pid: pid}}
  end

  @impl true
  def handle_cast({:apply_diff, :no_change, _new_tree}, state) do
    # No update needed
    {:noreply, state}
  end

  def handle_cast({:apply_diff, {:replace, new_tree}, _new_tree}, state) do
    # Full replacement
    if state.test_pid, do: send(state.test_pid, {:renderer_rendered, new_tree})
    require Raxol.Core.Runtime.Log

    Raxol.Core.Runtime.Log.info(
      "Renderer received full replacement diff: #{inspect(new_tree)}"
    )

    {:noreply, %{state | last_render: new_tree}}
  end

  def handle_cast(
        {:apply_diff, {:update, path, changes} = diff, new_tree},
        state
      ) do
    # Apply the diff to the last_render tree
    updated_tree = apply_diff_to_tree(state.last_render, diff)
    # For now, log and notify test_pid with the updated subtree at path
    updated_subtree = get_subtree_at_path(updated_tree, path)

    {new_state, _} =
      do_partial_render(path, updated_subtree, updated_tree, state)

    if state.test_pid,
      do:
        send(
          state.test_pid,
          {:renderer_partial_update, path, updated_subtree, updated_tree}
        )

    require Raxol.Core.Runtime.Log

    Raxol.Core.Runtime.Log.info(
      "Renderer applied partial update at path #{inspect(path)}. Updated subtree: #{inspect(updated_subtree)}"
    )

    {:noreply, %{new_state | last_render: updated_tree}}
  end

  # Helper to get the subtree at a given path
  defp get_subtree_at_path(tree, []), do: tree

  defp get_subtree_at_path(%{children: children}, [idx | rest]) do
    get_subtree_at_path(Enum.at(children, idx), rest)
  end

  # Helper for global process registration (optional, for singleton)
  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [Keyword.put(opts, :name, __MODULE__)]}
    }
  end
end
