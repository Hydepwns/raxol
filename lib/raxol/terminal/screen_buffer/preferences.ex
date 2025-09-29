defmodule Raxol.Terminal.ScreenBuffer.Preferences do
  @moduledoc """
  Manages screen buffer preferences and settings.
  """

  use Raxol.Core.Behaviours.BaseManager


  defstruct [
    :font_size,
    :line_height,
    :scrollback_size,
    :tab_width,
    :word_wrap,
    :auto_wrap,
    :cursor_style,
    :cursor_blink
  ]

  @type t :: %__MODULE__{
          font_size: non_neg_integer(),
          line_height: non_neg_integer(),
          scrollback_size: non_neg_integer(),
          tab_width: non_neg_integer(),
          word_wrap: boolean(),
          auto_wrap: boolean(),
          cursor_style: atom(),
          cursor_blink: boolean()
        }

  # BaseManager provides start_link/1
  # Usage: Raxol.Terminal.ScreenBuffer.Preferences.start_link(name: __MODULE__, ...)

  @impl true
  def init_manager(opts) do
    prefs = Keyword.get(opts, :preferences, default_preferences())
    state = case prefs do
      %__MODULE__{} = p -> p
      keyword when is_list(keyword) ->
        %__MODULE__{
          scrollback_size: Keyword.get(keyword, :scrollback_size, 1000),
          tab_width: Keyword.get(keyword, :tab_width, 8),
          auto_wrap: Keyword.get(keyword, :auto_wrap, true),
          cursor_style: Keyword.get(keyword, :cursor_style, :block),
          cursor_blink: Keyword.get(keyword, :cursor_blink, true)
        }
      _ -> default_preferences()
    end
    {:ok, state}
  end

  defp default_preferences do
    %__MODULE__{
      scrollback_size: 1000,
      tab_width: 8,
      auto_wrap: true,
      cursor_style: :block,
      cursor_blink: true
    }
  end

  def get do
    GenServer.call(__MODULE__, :get)
  end

  def set(preferences) do
    GenServer.call(__MODULE__, {:set, preferences})
  end

  @impl true
  def handle_manager_call(:get, _from, state) do
    {:reply, state, state}
  end

  @impl true
  def handle_manager_call({:set, preferences}, _from, _state) do
    {:reply, preferences, preferences}
  end
end
