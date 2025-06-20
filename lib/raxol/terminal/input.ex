defmodule Raxol.Terminal.Input do
  @moduledoc """
  Handles input processing for the terminal.
  """

  defstruct [
    :buffer,
    :state,
    :last_click,
    :last_drag,
    :last_release
  ]

  @type t :: %__MODULE__{
    buffer: list(),
    state: atom(),
    last_click: {integer(), integer(), atom()} | nil,
    last_drag: {integer(), integer(), atom()} | nil,
    last_release: {integer(), integer(), atom()} | nil
  }

  @doc """
  Creates a new input handler.
  """
  def new do
    %__MODULE__{
      buffer: [],
      state: :normal,
      last_click: nil,
      last_drag: nil,
      last_release: nil
    }
  end

  @doc """
  Handles a mouse click event.
  """
  def handle_click(input, x, y, button) do
    %{input | last_click: {x, y, button}}
  end

  @doc """
  Handles a mouse drag event.
  """
  def handle_drag(input, x, y, button) do
    %{input | last_drag: {x, y, button}}
  end

  @doc """
  Handles a mouse release event.
  """
  def handle_release(input, x, y, button) do
    %{input | last_release: {x, y, button}}
  end
end
