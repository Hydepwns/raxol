defmodule Raxol.UI.Components.Input.MultiLineInput.ClipboardHelper do
  @moduledoc """
  UI adapter for MultiLineInput's ClipboardHelper. Delegates to the implementation in
  Raxol.Components.Input.MultiLineInput.ClipboardHelper.
  """

  alias Raxol.Components.Input.MultiLineInput.ClipboardHelper, as: Impl
  alias Raxol.UI.Components.Input.MultiLineInput, as: State

  @doc """
  Copies the currently selected text to the clipboard.
  """
  def copy_selection(%State{} = state), do: Impl.copy_selection(state)

  @doc """
  Cuts the selected text (copies then deletes).
  """
  def cut_selection(%State{} = state), do: Impl.cut_selection(state)

  @doc """
  Initiates a paste operation from clipboard.
  """
  def paste(%State{} = state), do: Impl.paste(state)
end
