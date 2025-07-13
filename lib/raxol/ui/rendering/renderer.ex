defmodule Raxol.UI.Rendering.Renderer do
  @moduledoc """
  GenServer responsible for managing rendering state and applying animation settings.
  Receives commands from the rendering pipeline and coordinates rendering actions.
  """

  use GenServer
  require Raxol.Core.Runtime.Log
  require Logger

  # Public API

  @doc """
  Starts the rendering process.
  """
  def start_link(opts \\ []) do
    name =
      if Mix.env() == :test do
        Raxol.Test.ProcessNaming.unique_name(__MODULE__, opts)
      else
        Keyword.get(opts, :name)
      end

    gen_server_opts = Keyword.delete(opts, :name)

    if name do
      GenServer.start_link(__MODULE__, %{}, [name: name] ++ gen_server_opts)
    else
      GenServer.start_link(__MODULE__, %{}, gen_server_opts)
    end
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

  def apply_diff({:update, _path, _changes} = diff, new_tree) do
    GenServer.cast(__MODULE__, {:apply_diff, diff, new_tree})
  end

  # Recursively applies a diff to a tree, returning the updated tree
  defp apply_diff_to_tree(
         tree,
         {:update, [], %{diffs: diffs, type: :indexed_children}}
       ) do
    # At root, apply all child diffs from the indexed_children format
    apply_child_diffs(tree, diffs)
  end

  defp apply_diff_to_tree(tree, {:update, [], changes}) when is_list(changes) do
    # At root, apply all child diffs (legacy format)
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

  @impl GenServer
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

  @impl GenServer
  def handle_cast({:set_animation_settings, settings}, state) do
    {:noreply, %{state | animation_settings: settings}}
  end

  @impl GenServer
  def handle_cast({:render, data}, state) do
    require Logger

    Logger.debug(
      "[Renderer] handle_cast {:render, data} called with data=#{inspect(data)}, test_pid=#{inspect(state.test_pid)}"
    )

    # Convert the tree to paint operations
    ops = ui_tree_to_terminal_ops_with_lines(data)

    # Update the buffer for the full tree render
    {new_state, _} = do_partial_render([], data, data, state)

    if state.test_pid do
      Logger.debug(
        "[Renderer] Sending {:renderer_rendered, ops} to test_pid #{inspect(state.test_pid)} with ops=#{inspect(ops)}"
      )

      send(state.test_pid, {:renderer_rendered, ops})
    else
      Logger.debug(
        "[Renderer] No test_pid set, not sending {:renderer_rendered, ops} message"
      )
    end

    require Raxol.Core.Runtime.Log

    Raxol.Core.Runtime.Log.info(
      "Renderer received render: #{inspect(data)} (buffer updated)"
    )

    {:noreply, %{new_state | last_render: data}}
  end

  @impl GenServer
  def handle_cast({:set_test_pid, pid}, state) do
    {:noreply, %{state | test_pid: pid}}
  end

  @impl GenServer
  def handle_cast({:apply_diff, :no_change, _new_tree}, state) do
    # No update needed
    {:noreply, state}
  end

  def handle_cast({:apply_diff, {:replace, new_tree}, _new_tree}, state) do
    # Full replacement
    # Convert the tree to paint operations for consistency with other handlers
    ops = ui_tree_to_terminal_ops_with_lines(new_tree)

    # Update the buffer for the full tree render
    {new_state, _} = do_partial_render([], new_tree, new_tree, state)

    if state.test_pid, do: send(state.test_pid, {:renderer_rendered, ops})
    require Raxol.Core.Runtime.Log

    Raxol.Core.Runtime.Log.info(
      "Renderer received full replacement diff: #{inspect(new_tree)}"
    )

    {:noreply, %{new_state | last_render: new_tree}}
  end

  @impl GenServer
  def handle_cast(
        {:apply_diff, {:update, path, _changes} = diff, new_tree},
        state
      ) do
    Raxol.Core.Runtime.Log.debug(
      "Renderer: Received apply_diff message: #{inspect(diff)}, new_tree: #{inspect(new_tree)}, test_pid: #{inspect(state.test_pid)}"
    )

    Raxol.Core.Runtime.Log.debug(
      "Renderer: state.last_render: #{inspect(state.last_render)}"
    )

    # Apply the diff to the last_render tree
    updated_tree = apply_diff_to_tree(state.last_render, diff)

    Raxol.Core.Runtime.Log.debug(
      "Renderer: updated_tree: #{inspect(updated_tree)}"
    )

    # For now, log and notify test_pid with the updated subtree at path
    updated_subtree = get_subtree_at_path(updated_tree, path)

    Raxol.Core.Runtime.Log.debug(
      "Renderer: updated_subtree: #{inspect(updated_subtree)}"
    )

    {new_state, _} =
      do_partial_render(path, updated_subtree, updated_tree, state)

    if state.test_pid do
      Raxol.Core.Runtime.Log.debug(
        "Renderer: Sending {:renderer_partial_update, #{inspect(path)}, #{inspect(updated_subtree)}, #{inspect(updated_tree)}} to test_pid #{inspect(state.test_pid)}"
      )

      send(
        state.test_pid,
        {:renderer_partial_update, path, updated_subtree, updated_tree}
      )
    else
      Raxol.Core.Runtime.Log.debug(
        "Renderer: No test_pid set, not sending partial update message"
      )
    end

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
