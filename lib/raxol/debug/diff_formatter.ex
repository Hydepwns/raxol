defmodule Raxol.Debug.DiffFormatter do
  @moduledoc """
  Pure functions for formatting Snapshot changes into styled display lines.

  Converts the `{:changed, path, old, new}`, `{:added, path, val}`, and
  `{:removed, path, val}` tuples from `Snapshot.diff/2` into text lines
  with color indicators suitable for the debugger UI.
  """

  alias Raxol.Debug.Snapshot

  @type formatted_line :: %{
          type: :changed | :added | :removed,
          path_str: String.t(),
          detail: String.t()
        }

  @doc """
  Formats a list of Snapshot changes into displayable lines.

  ## Parameters
    - `changes` - List of `Snapshot.change()` tuples

  ## Returns
    List of `formatted_line()` maps.
  """
  @spec format_changes([Snapshot.change()]) :: [formatted_line()]
  def format_changes(changes) when is_list(changes) do
    Enum.map(changes, &format_one/1)
  end

  def format_changes(_), do: []

  @doc """
  Formats a snapshot's internal diff (model_before vs model_after).
  """
  @spec format_snapshot_diff(Snapshot.t()) :: [formatted_line()]
  def format_snapshot_diff(%Snapshot{} = snap) do
    snap.model_before
    |> Snapshot.diff(snap.model_after)
    |> format_changes()
  end

  @doc """
  Renders a formatted line into a display string with prefix indicator.

  Returns `{prefix, text}` where prefix is "+", "-", or "~".
  """
  @spec render_line(formatted_line()) :: {String.t(), String.t()}
  def render_line(%{type: :added} = line) do
    {"+ ", "[#{line.path_str}] #{line.detail}"}
  end

  def render_line(%{type: :removed} = line) do
    {"- ", "[#{line.path_str}] #{line.detail}"}
  end

  def render_line(%{type: :changed} = line) do
    {"~ ", "[#{line.path_str}] #{line.detail}"}
  end

  @doc "Formats a key path list into a readable dot-separated string."
  @spec format_path([term()]) :: String.t()
  def format_path([]), do: "(root)"

  def format_path(path) when is_list(path) do
    Enum.map_join(path, ".", fn
      key when is_atom(key) -> Atom.to_string(key)
      key when is_binary(key) -> key
      key -> inspect(key)
    end)
  end

  # -- Private --

  defp format_one({:changed, path, old, new}) do
    %{
      type: :changed,
      path_str: format_path(path),
      detail: "#{inspect_short(old)} -> #{inspect_short(new)}"
    }
  end

  defp format_one({:added, path, value}) do
    %{
      type: :added,
      path_str: format_path(path),
      detail: inspect_short(value)
    }
  end

  defp format_one({:removed, path, value}) do
    %{
      type: :removed,
      path_str: format_path(path),
      detail: inspect_short(value)
    }
  end

  defp inspect_short(term) do
    str = inspect(term, limit: 5, printable_limit: 40)

    if String.length(str) > 40 do
      String.slice(str, 0, 37) <> "..."
    else
      str
    end
  end
end
