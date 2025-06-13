defmodule Raxol.Terminal.Clipboard.Sync do
  @moduledoc """
  Handles clipboard synchronization between different terminal instances.
  """

  defstruct [:subscribers]

  @type t :: %__MODULE__{
    subscribers: list(pid())
  }

  @doc """
  Creates a new clipboard sync instance.
  """
  @spec new() :: t()
  def new() do
    %__MODULE__{
      subscribers: []
    }
  end

  @doc """
  Broadcasts clipboard content to all subscribers.
  """
  @spec broadcast(t(), String.t(), String.t()) :: {:ok, t()}
  def broadcast(sync, content, format) do
    for subscriber <- sync.subscribers do
      send(subscriber, {:clipboard_update, content, format})
    end

    {:ok, sync}
  end

  @doc """
  Adds a subscriber to receive clipboard updates.
  """
  @spec add_subscriber(t(), pid()) :: {:ok, t()}
  def add_subscriber(sync, pid) do
    {:ok, %{sync | subscribers: [pid | sync.subscribers]}}
  end

  @doc """
  Removes a subscriber from receiving clipboard updates.
  """
  @spec remove_subscriber(t(), pid()) :: {:ok, t()}
  def remove_subscriber(sync, pid) do
    {:ok, %{sync | subscribers: List.delete(sync.subscribers, pid)}}
  end
end
