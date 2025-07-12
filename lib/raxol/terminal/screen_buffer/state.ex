defmodule Raxol.Terminal.ScreenBuffer.State do
  @moduledoc false

  def init do
    %{
      stack: [],
      current: :normal
    }
  end

  def get_stack(state) do
    state.stack
  end

  def update_stack(state, stack) do
    %{state | stack: stack}
  end

  def save(state) do
    %{state | stack: [state.current | state.stack]}
  end

  def restore(state) do
    case state.stack do
      [current | rest] -> %{state | current: current, stack: rest}
      [] -> state
    end
  end

  def has_saved_states?(state) do
    length(state.stack) > 0
  end

  def get_saved_states_count(state) do
    length(state.stack)
  end

  def clear_saved_states(state) do
    %{state | stack: []}
  end

  def get_current(state) do
    state.current
  end

  def update_current(state, new_state) do
    %{state | current: new_state}
  end
end
