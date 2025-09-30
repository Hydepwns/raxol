defmodule Raxol.Terminal.ScreenBuffer.Cloud do
  @moduledoc """
  Manages cloud-related settings for the screen buffer.
  """

  use Raxol.Core.Behaviours.BaseManager

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

  # BaseManager provides start_link/1
  # Usage: Raxol.Terminal.ScreenBuffer.Cloud.start_link(name: __MODULE__, ...)

  @impl true
  def init_manager(opts) do
    config = Keyword.get(opts, :config, default_config())

    state =
      case config do
        %__MODULE__{} = c ->
          c

        keyword when is_list(keyword) ->
          %__MODULE__{
            sync_enabled: Keyword.get(keyword, :sync_enabled, false),
            auto_sync: Keyword.get(keyword, :auto_sync, true),
            sync_interval: Keyword.get(keyword, :sync_interval, 5000)
          }

        _ ->
          default_config()
      end

    {:ok, state}
  end

  defp default_config do
    %__MODULE__{
      sync_enabled: false,
      auto_sync: true,
      sync_interval: 5000
    }
  end

  def get_config do
    GenServer.call(__MODULE__, :get_config)
  end

  def set_config(config) do
    GenServer.call(__MODULE__, {:set_config, config})
  end

  @impl true
  def handle_manager_call(:get_config, _from, state) do
    {:reply, state, state}
  end

  @impl true
  def handle_manager_call({:set_config, config}, _from, _state) do
    {:reply, config, config}
  end
end
