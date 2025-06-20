defmodule Raxol.Terminal.Configuration do
  @moduledoc """
  Configuration management for the terminal emulator.
  """

  require Raxol.Core.Runtime.Log

  alias Raxol.Terminal.ANSI.TerminalState

  @type t :: %__MODULE__{
          width: non_neg_integer(),
          height: non_neg_integer(),
          scrollback_size: non_neg_integer(),
          tab_stops: [non_neg_integer()],
          charset_state: map(),
          mode_state: map(),
          saved_state: [TerminalState.t()]
        }

  defstruct [
    :width,
    :height,
    :scrollback_size,
    :tab_stops,
    :charset_state,
    :mode_state,
    :saved_state
  ]

  @doc """
  Creates a new configuration with default values.
  """
  def new(opts \\ []) do
    %__MODULE__{
      width: Keyword.get(opts, :width, 80),
      height: Keyword.get(opts, :height, 24),
      scrollback_size: Keyword.get(opts, :scrollback_size, 1000),
      tab_stops:
        Keyword.get(opts, :tab_stops, [8, 16, 24, 32, 40, 48, 56, 64, 72, 80]),
      charset_state: %{},
      mode_state: %{},
      saved_state: []
    }
  end

  @doc """
  Saves the current terminal state.
  """
  def save_state(state, config) do
    %{config | saved_state: [state | config.saved_state]}
  end

  @doc """
  Restores the most recently saved terminal state.
  """
  def restore_state(config) do
    case config.saved_state do
      [state | rest] -> {state, %{config | saved_state: rest}}
      [] -> {nil, config}
    end
  end

  @doc """
  Applies restored data to the configuration.
  """
  def apply_restored_data(state, _data, _opts) do
    state
  end

  @doc """
  Updates the configuration with new values.
  """
  @spec update(t(), map()) :: t()
  def update(config, updates) when is_map(updates) do
    Map.merge(config, updates)
  end

  def update(config, updates) when is_list(updates) do
    Enum.reduce(updates, config, fn {key, value}, acc ->
      Map.put(acc, key, value)
    end)
  end
end
