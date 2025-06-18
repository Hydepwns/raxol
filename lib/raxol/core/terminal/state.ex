defmodule Raxol.Core.Terminal.State do
  @moduledoc """
  Represents the core state of a terminal instance.

  This module defines the minimal state structure required for terminal operations,
  particularly for handling color palette OSC (Operating System Command) operations.
  The state maintains a mapping of color indices to their RGB values.

  ## Color Palette

  The color palette is stored as a map where:
  * Keys are color indices (integers)
  * Values are RGB color tuples `{r, g, b}` where each component is 0-255

  ## Usage

  ```elixir
  # Create a new state with default palette
  state = %Raxol.Core.Terminal.State{}

  # Create state with custom palette
  state = %Raxol.Core.Terminal.State{
    palette: %{
      0 => {0, 0, 0},       # Black
      1 => {255, 0, 0},     # Red
      2 => {0, 255, 0},     # Green
      3 => {255, 255, 0}    # Yellow
    }
  }
  ```
  """

  @doc """
  Defines the terminal state structure.

  ## Fields

    * `:palette` - Map of color indices to RGB values
  """
  defstruct palette: %{}
end
