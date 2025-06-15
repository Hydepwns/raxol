defmodule Raxol.Terminal.ScreenBuffer.Cloud do
  @moduledoc """
  Manages cloud-related settings for the screen buffer.
  """

  use GenServer

  defstruct [
    :sync_enabled,
    :auto_sync,
    :sync_interval
  ]

  @type t :: %__MODULE__{
          sync_enabled: boolean(),
          auto_sync: boolean(),
          sync_interval: non_neg_integer()
        }

  def start_link(_) do
    GenServer.start_link(__MODULE__, default_config(), name: __MODULE__)
  end

  def init(config) do
    {:ok, config}
  end

  @doc """
  Gets the current cloud configuration.
  """
  def get_config do
    GenServer.call(__MODULE__, :get_config)
  end

  @doc """
  Sets new cloud configuration.
  """
  def set_config(config) do
    GenServer.call(__MODULE__, {:set_config, config})
  end

  def handle_call(:get_config, _from, state) do
    {:reply, state, state}
  end

  def handle_call({:set_config, config}, _from, _state) do
    {:reply, config, config}
  end

  defp default_config do
    %__MODULE__{
      sync_enabled: false,
      auto_sync: false,
      sync_interval: 300
    }
  end
end
