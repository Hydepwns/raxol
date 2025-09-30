defmodule Raxol.Terminal.Tooltip do
  @moduledoc """
  Tooltip display functionality for terminal UI.

  This module provides tooltip rendering capabilities for terminal applications,
  allowing contextual help text to appear on hover or focus.
  """

  use Raxol.Core.Behaviours.BaseManager

  require Logger

  @doc """
  Shows a tooltip with the given text at the current cursor position.

  ## Parameters
    - `text` - The text to display in the tooltip

  ## Examples
      
      Raxol.Terminal.Tooltip.show("Click to submit")
  """
  @spec show(String.t()) :: :ok
  def show(text) when is_binary(text) do
    GenServer.cast(__MODULE__, {:show, text})
  end

  @doc """
  Hides the currently displayed tooltip.

  ## Examples
      
      Raxol.Terminal.Tooltip.hide()
  """
  @spec hide() :: :ok
  def hide do
    GenServer.cast(__MODULE__, :hide)
  end

  @doc """
  Starts the tooltip server.
  """

  # BaseManager provides start_link/1 with proper option handling

  # BaseManager callbacks

  @impl Raxol.Core.Behaviours.BaseManager
  def init_manager(_opts) do
    {:ok, %{visible: false, text: "", position: {0, 0}}}
  end

  @impl Raxol.Core.Behaviours.BaseManager
  def handle_manager_cast({:show, text}, state) do
    # In a real implementation, this would render the tooltip
    Logger.debug("Showing tooltip: #{text}")
    {:noreply, %{state | visible: true, text: text}}
  end

  def handle_manager_cast(:hide, state) do
    Logger.debug("Hiding tooltip")
    {:noreply, %{state | visible: false, text: ""}}
  end

  @impl Raxol.Core.Behaviours.BaseManager
  def handle_manager_call(:get_state, _from, state) do
    {:reply, state, state}
  end
end
