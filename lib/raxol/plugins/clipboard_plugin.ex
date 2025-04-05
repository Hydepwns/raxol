defmodule Raxol.Plugins.ClipboardPlugin do
  @moduledoc """
  Plugin for clipboard operations in Raxol.
  """

  use Raxol.Plugin

  @impl true
  def init(_opts) do
    {:ok, %{}}
  end

  @impl true
  def handle_event({:key, key}, state) do
    case key do
      "y" -> yank_selection(state)
      "d" -> delete_selection(state)
      _ -> {:ok, state}
    end
  end

  defp yank_selection(state) do
    case get_selected_text(state) do
      {:ok, text} -> 
        set_clipboard_content(text)
        {:ok, state}
      _ -> {:ok, state}
    end
  end

  defp delete_selection(state) do
    case get_selected_text(state) do
      {:ok, _text} -> 
        {:ok, clear_selection(state)}
      _ -> {:ok, state}
    end
  end

  defp get_selected_text(%{selection: nil}), do: {:error, :no_selection}
  defp get_selected_text(%{selection: {start_pos, end_pos}, buffer: buffer}) do
    text = buffer
    |> Enum.slice(start_pos..end_pos)
    |> Enum.join("\n")
    {:ok, text}
  end

  defp set_clipboard_content(text) do
    case :os.type() do
      {:unix, :darwin} ->
        System.cmd("pbcopy", [], input: text)
      {:unix, _} ->
        System.cmd("xclip", ["-selection", "clipboard"], input: text)
      {:win32, _} ->
        System.cmd("clip", [], input: text)
    end
    :ok
  end

  defp clear_selection(state) do
    %{state | selection: nil}
  end
end 