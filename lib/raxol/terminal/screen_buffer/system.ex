defmodule Raxol.Terminal.ScreenBuffer.System do
  @moduledoc '''
  Manages system-related settings for the screen buffer.
  '''

  use GenServer

  defstruct [
    :update_interval,
    :auto_update,
    :debug_mode
  ]

  @type t :: %__MODULE__{
          update_interval: non_neg_integer(),
          auto_update: boolean(),
          debug_mode: boolean()
        }

  def start_link(_) do
    GenServer.start_link(__MODULE__, default_settings(), name: __MODULE__)
  end

  def init(settings) do
    %__MODULE__{
      update_interval: Keyword.get(settings, :update_interval, 16),
      auto_update: Keyword.get(settings, :auto_update, true),
      debug_mode: Keyword.get(settings, :debug_mode, false)
    }
  end

  def init do
    %__MODULE__{
      update_interval: 16,
      auto_update: true,
      debug_mode: false
    }
  end

  defp default_settings do
    %__MODULE__{
      update_interval: 16,
      auto_update: true,
      debug_mode: false
    }
  end

  @doc '''
  Gets the current update settings.
  '''
  def get_update_settings do
    GenServer.call(__MODULE__, :get_update_settings)
  end

  def handle_call(:get_update_settings, _from, state) do
    {:reply, state, state}
  end
end
