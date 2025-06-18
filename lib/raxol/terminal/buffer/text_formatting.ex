defmodule Raxol.Terminal.Buffer.TextFormatting do
  @moduledoc '''
  Manages terminal text formatting operations.
  '''

  alias Raxol.Terminal.Buffer.Cell

  @doc '''
  Applies bold formatting to a cell.
  '''
  def apply_bold(%Cell{} = cell) do
    update_attributes(cell, :bold, true)
  end

  @doc '''
  Applies italic formatting to a cell.
  '''
  def apply_italic(%Cell{} = cell) do
    update_attributes(cell, :italic, true)
  end

  @doc '''
  Applies underline formatting to a cell.
  '''
  def apply_underline(%Cell{} = cell) do
    update_attributes(cell, :underline, true)
  end

  @doc '''
  Applies blink formatting to a cell.
  '''
  def apply_blink(%Cell{} = cell) do
    update_attributes(cell, :blink, true)
  end

  @doc '''
  Applies reverse video formatting to a cell.
  '''
  def apply_reverse(%Cell{} = cell) do
    update_attributes(cell, :reverse, true)
  end

  @doc '''
  Applies invisible formatting to a cell.
  '''
  def apply_invisible(%Cell{} = cell) do
    update_attributes(cell, :invisible, true)
  end

  @doc '''
  Removes bold formatting from a cell.
  '''
  def remove_bold(%Cell{} = cell) do
    update_attributes(cell, :bold, false)
  end

  @doc '''
  Removes italic formatting from a cell.
  '''
  def remove_italic(%Cell{} = cell) do
    update_attributes(cell, :italic, false)
  end

  @doc '''
  Removes underline formatting from a cell.
  '''
  def remove_underline(%Cell{} = cell) do
    update_attributes(cell, :underline, false)
  end

  @doc '''
  Removes blink formatting from a cell.
  '''
  def remove_blink(%Cell{} = cell) do
    update_attributes(cell, :blink, false)
  end

  @doc '''
  Removes reverse video formatting from a cell.
  '''
  def remove_reverse(%Cell{} = cell) do
    update_attributes(cell, :reverse, false)
  end

  @doc '''
  Removes invisible formatting from a cell.
  '''
  def remove_invisible(%Cell{} = cell) do
    update_attributes(cell, :invisible, false)
  end

  @doc '''
  Checks if a cell has bold formatting.
  '''
  def bold?(%Cell{} = cell) do
    get_attribute(cell, :bold)
  end

  @doc '''
  Checks if a cell has italic formatting.
  '''
  def italic?(%Cell{} = cell) do
    get_attribute(cell, :italic)
  end

  @doc '''
  Checks if a cell has underline formatting.
  '''
  def underline?(%Cell{} = cell) do
    get_attribute(cell, :underline)
  end

  @doc '''
  Checks if a cell has blink formatting.
  '''
  def blink?(%Cell{} = cell) do
    get_attribute(cell, :blink)
  end

  @doc '''
  Checks if a cell has reverse video formatting.
  '''
  def reverse?(%Cell{} = cell) do
    get_attribute(cell, :reverse)
  end

  @doc '''
  Checks if a cell has invisible formatting.
  '''
  def invisible?(%Cell{} = cell) do
    get_attribute(cell, :invisible)
  end

  @doc '''
  Resets all formatting attributes on a cell.
  '''
  def reset_formatting(%Cell{} = cell) do
    %{cell | attributes: %{}}
  end

  defp update_attributes(%Cell{} = cell, key, value) do
    attributes = Map.put(cell.attributes, key, value)
    %{cell | attributes: attributes}
  end

  defp get_attribute(%Cell{} = cell, key) do
    Map.get(cell.attributes, key, false)
  end

  def new, do: %{}
end
