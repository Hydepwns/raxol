defmodule Raxol.Core.Focus do
  @moduledoc """
  Convenience module for focus management in TEA applications.

  Wraps `Raxol.Core.FocusManager` with a simpler API designed for use
  inside `init/1` and `view/1` callbacks. Opt-in: if `setup_focus/1` is
  never called, FocusServer is never started and all queries return safe
  defaults (nil / false).

  ## Usage

      def init(_context) do
        setup_focus([
          {"username", 0},
          {"password", 1},
          {"submit", 2}
        ])
        %{username: "", password: ""}
      end

      def view(model) do
        # focused?/1 is safe to call even if FocusServer isn't running
        text_input(id: "username", focused: focused?("username"))
      end
  """

  alias Raxol.Core.FocusManager

  @doc """
  Registers focusable elements and sets initial focus to the first one.

  Accepts a list of tuples:
    - `{id, tab_index}` -- register with default opts
    - `{id, tab_index, opts}` -- register with custom opts

  Elements are sorted by `tab_index`; the lowest gets initial focus.
  """
  @spec setup_focus([{binary(), integer()} | {binary(), integer(), keyword()}]) ::
          :ok
  def setup_focus(elements) when is_list(elements) do
    FocusManager.ensure_started()

    sorted =
      elements
      |> Enum.map(&normalize_element/1)
      |> Enum.sort_by(fn {_id, tab_index, _opts} -> tab_index end)

    Enum.each(sorted, fn {id, tab_index, opts} ->
      FocusManager.register_focusable(id, tab_index, opts)
    end)

    case sorted do
      [{first_id, _, _} | _] -> FocusManager.set_initial_focus(first_id)
      [] -> :ok
    end

    :ok
  end

  @doc """
  Returns true if the given element currently has focus.

  Safe to call from `view/1` -- returns false if FocusServer is not running.
  """
  @spec focused?(binary()) :: boolean()
  def focused?(element_id) do
    if focus_server_running?() do
      FocusManager.has_focus?(element_id)
    else
      false
    end
  end

  @doc """
  Returns the ID of the currently focused element, or nil.

  Safe to call at any time -- returns nil if FocusServer is not running.
  """
  @spec current_focus() :: binary() | nil
  def current_focus do
    if focus_server_running?() do
      FocusManager.get_focused_element()
    else
      nil
    end
  end

  defp normalize_element({id, tab_index}), do: {id, tab_index, []}
  defp normalize_element({id, tab_index, opts}), do: {id, tab_index, opts}

  defp focus_server_running? do
    Process.whereis(Raxol.Core.FocusManager.FocusServer) != nil
  end
end
