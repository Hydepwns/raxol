defmodule Raxol.Terminal.Buffer.CommandHandler do
  @moduledoc """
  Handles buffer commands for the unified buffer manager.
  """

  alias Raxol.Terminal.Buffer.UnifiedManager

  def handle_command(state, {:set_cell, x, y, cell}) do
    UnifiedManager.set_cell(state, x, y, cell)
  end

  def handle_command(state, {:fill_region, x, y, width, height, cell}) do
    UnifiedManager.fill_region(state, x, y, width, height, cell)
  end

  def handle_command(state, {:scroll_region, x, y, width, height, amount}),
    do: UnifiedManager.scroll_region(state, x, y, width, height, amount)

  def handle_command(state, :clear), do: UnifiedManager.clear(state)

  def handle_command(state, {:resize, width, height}),
    do: UnifiedManager.resize(state, width, height)

  def handle_command(_state, _command), do: {:error, :unknown_command}
end
