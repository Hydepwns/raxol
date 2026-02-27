defmodule Raxol.Terminal.ScreenBuffer.Theme do
  @moduledoc """
  Deprecated: This module is not used in the codebase.

  Originally intended for screen buffer themes but never integrated.
  Use `Raxol.UI.Theming` for theme management instead.
  """

  use Raxol.Core.Behaviours.BaseManager

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

  # BaseManager provides start_link/1
  # Usage: Raxol.Terminal.ScreenBuffer.Theme.start_link(name: __MODULE__, ...)

  @impl true
  def init_manager(opts) do
    theme = Keyword.get(opts, :theme, default_theme())

    state =
      case theme do
        %__MODULE__{} = t ->
          t

        keyword when is_list(keyword) ->
          %__MODULE__{
            name: Keyword.get(keyword, :name, "default"),
            foreground: Keyword.get(keyword, :foreground, "#FFFFFF"),
            background: Keyword.get(keyword, :background, "#000000"),
            cursor: Keyword.get(keyword, :cursor, "#FFFFFF"),
            selection: Keyword.get(keyword, :selection, "#444444")
          }

        _ ->
          default_theme()
      end

    {:ok, state}
  end

  def current do
    GenServer.call(__MODULE__, :current)
  end

  def light do
    GenServer.call(__MODULE__, {:set, light_theme()})
  end

  @impl true
  def handle_manager_call(:current, _from, state) do
    {:reply, state, state}
  end

  @impl true
  def handle_manager_call({:set, theme}, _from, _state) do
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
