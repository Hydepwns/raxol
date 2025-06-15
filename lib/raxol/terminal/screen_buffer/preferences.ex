defmodule Raxol.Terminal.ScreenBuffer.Preferences do
  @moduledoc """
  Manages screen buffer preferences and settings.
  """

  use GenServer

  defstruct [
    :font_size,
    :line_height,
    :scrollback_size,
    :tab_width,
    :word_wrap
  ]

  @type t :: %__MODULE__{
          font_size: non_neg_integer(),
          line_height: non_neg_integer(),
          scrollback_size: non_neg_integer(),
          tab_width: non_neg_integer(),
          word_wrap: boolean()
        }

  def start_link(_) do
    GenServer.start_link(__MODULE__, default_preferences(), name: __MODULE__)
  end

  def init(preferences) do
    {:ok, preferences}
  end

  @doc """
  Gets the current preferences.
  """
  def get do
    GenServer.call(__MODULE__, :get)
  end

  @doc """
  Sets new preferences.
  """
  def set(preferences) do
    GenServer.call(__MODULE__, {:set, preferences})
  end

  def handle_call(:get, _from, state) do
    {:reply, state, state}
  end

  def handle_call({:set, preferences}, _from, _state) do
    {:reply, preferences, preferences}
  end

  defp default_preferences do
    %__MODULE__{
      font_size: 12,
      line_height: 20,
      scrollback_size: 1000,
      tab_width: 8,
      word_wrap: true
    }
  end
end
