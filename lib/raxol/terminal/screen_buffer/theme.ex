defmodule Raxol.Terminal.ScreenBuffer.Theme do
  @moduledoc '''
  Manages themes for the screen buffer.
  '''

  use GenServer

  defstruct [
    :name,
    :foreground,
    :background,
    :cursor,
    :selection
  ]

  @type t :: %__MODULE__{
          name: String.t(),
          foreground: String.t(),
          background: String.t(),
          cursor: String.t(),
          selection: String.t()
        }

  def start_link(_) do
    GenServer.start_link(__MODULE__, default_theme(), name: __MODULE__)
  end

  def init(theme) do
    %__MODULE__{
      name: Keyword.get(theme, :name, "default"),
      foreground: Keyword.get(theme, :foreground, "#FFFFFF"),
      background: Keyword.get(theme, :background, "#000000"),
      cursor: Keyword.get(theme, :cursor, "#FFFFFF"),
      selection: Keyword.get(theme, :selection, "#444444")
    }
  end

  def init do
    %__MODULE__{
      name: "default",
      foreground: "#FFFFFF",
      background: "#000000",
      cursor: "#FFFFFF",
      selection: "#444444"
    }
  end

  @doc '''
  Gets the current theme.
  '''
  def current do
    GenServer.call(__MODULE__, :current)
  end

  @doc '''
  Sets the light theme.
  '''
  def light do
    GenServer.call(__MODULE__, {:set, light_theme()})
  end

  def handle_call(:current, _from, state) do
    {:reply, state, state}
  end

  def handle_call({:set, theme}, _from, _state) do
    {:reply, theme, theme}
  end

  defp default_theme do
    %__MODULE__{
      name: "default",
      foreground: "#FFFFFF",
      background: "#000000",
      cursor: "#FFFFFF",
      selection: "#444444"
    }
  end

  defp light_theme do
    %__MODULE__{
      name: "light",
      foreground: "#000000",
      background: "#FFFFFF",
      cursor: "#000000",
      selection: "#CCCCCC"
    }
  end
end
