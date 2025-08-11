defmodule Raxol.Terminal.Tooltip do
  @moduledoc """
  Tooltip display functionality for terminal UI.

  This module provides tooltip rendering capabilities for terminal applications,
  allowing contextual help text to appear on hover or focus.
  """

  use GenServer
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
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  # GenServer callbacks

  @impl true
  def init(_opts) do
    {:ok, %{visible: false, text: "", position: {0, 0}}}
  end

  @impl true
  def handle_cast({:show, text}, state) do
    # In a real implementation, this would render the tooltip
    Logger.debug("Showing tooltip: #{text}")
    {:noreply, %{state | visible: true, text: text}}
  end

  @impl true
  def handle_cast(:hide, state) do
    Logger.debug("Hiding tooltip")
    {:noreply, %{state | visible: false, text: ""}}
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end
end
