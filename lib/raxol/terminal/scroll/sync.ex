defmodule Raxol.Terminal.Scroll.Sync do
  @moduledoc """
  Handles scroll synchronization across terminal splits.
  """

  @type t :: %__MODULE__{
    sync_enabled: boolean(),
    last_sync: non_neg_integer()
  }

  defstruct [
    :sync_enabled,
    :last_sync
  ]

  @doc """
  Creates a new sync instance.
  """
  @spec new() :: t()
  def new do
    %__MODULE__{
      sync_enabled: true,
      last_sync: System.monotonic_time()
    }
  end

  @doc """
  Synchronizes scroll operations across splits.
  """
  @spec sync(t(), :up | :down, non_neg_integer()) :: t()
  def sync(sync, direction, lines) do
    # Update last sync time
    %{sync | last_sync: System.monotonic_time()}
  end
end
