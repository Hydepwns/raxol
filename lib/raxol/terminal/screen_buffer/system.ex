defmodule Raxol.Terminal.ScreenBuffer.System do
  @moduledoc """
  Manages system-related settings for the screen buffer.
  """

  use Raxol.Core.Behaviours.BaseManager

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

  # BaseManager provides start_link/1
  # Usage: Raxol.Terminal.ScreenBuffer.System.start_link(name: __MODULE__, ...)

  @impl true
  def init_manager(opts) do
    settings = Keyword.get(opts, :settings, default_settings())

    state =
      case settings do
        %__MODULE__{} = s ->
          s

        keyword when is_list(keyword) ->
          %__MODULE__{
            update_interval: Keyword.get(keyword, :update_interval, 16),
            auto_update: Keyword.get(keyword, :auto_update, true),
            debug_mode: Keyword.get(keyword, :debug_mode, false)
          }

        _ ->
          default_settings()
      end

    {:ok, state}
  end

  defp default_settings do
    %__MODULE__{
      update_interval: 16,
      auto_update: true,
      debug_mode: false
    }
  end

  def get_update_settings do
    GenServer.call(__MODULE__, :get_update_settings)
  end

  @impl true
  def handle_manager_call(:get_update_settings, _from, state) do
    {:reply, state, state}
  end
end
