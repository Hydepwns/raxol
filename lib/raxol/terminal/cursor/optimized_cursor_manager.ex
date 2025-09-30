defmodule Raxol.Terminal.Cursor.OptimizedCursorManager do
  @moduledoc """
  Optimized cursor manager using BaseManager behavior to reduce boilerplate.
  Demonstrates the performance benefits of our consolidated base behaviors.
  """

  use Raxol.Core.Behaviours.BaseManager

  require Raxol.Core.Runtime.Log

  defstruct row: 0,
            col: 0,
            visible: true,
            blinking: true,
            style: :block,
            color: nil,
            saved_row: nil,
            saved_col: nil,
            saved_style: nil,
            saved_visible: nil,
            saved_blinking: nil,
            saved_color: nil,
            top_margin: 0,
            bottom_margin: 23,
            blink_timer: nil,
            state: :visible,
            position: {0, 0},
            blink: true,
            custom_shape: nil,
            custom_dimensions: nil,
            blink_rate: 530,
            saved_position: nil,
            history: [],
            history_index: 0,
            history_limit: 100,
            shape: {1, 1}

  @type cursor_style :: :block | :underline | :bar
  @type color :: {non_neg_integer(), non_neg_integer(), non_neg_integer()} | nil

  ## BaseManager Implementation

  @impl Raxol.Core.Behaviours.BaseManager
  def init_manager(opts) do
    state = %__MODULE__{
      row: Keyword.get(opts, :row, 0),
      col: Keyword.get(opts, :col, 0),
      visible: Keyword.get(opts, :visible, true),
      blinking: Keyword.get(opts, :blinking, true),
      style: Keyword.get(opts, :style, :block),
      bottom_margin: Keyword.get(opts, :bottom_margin, 23),
      blink_rate: Keyword.get(opts, :blink_rate, 530),
      history_limit: Keyword.get(opts, :history_limit, 100)
    }

    # Start blink timer if blinking is enabled
    timer =
      if state.blinking do
        :timer.send_interval(state.blink_rate, :blink_tick)
      else
        nil
      end

    final_state = %{state | blink_timer: timer}
    {:ok, final_state}
  end

  ## Client API

  def move_to(server \\ __MODULE__, row, col) do
    GenServer.call(server, {:move_to, row, col})
  end

  def set_visibility(server \\ __MODULE__, visible) do
    GenServer.call(server, {:set_visibility, visible})
  end

  def set_style(server \\ __MODULE__, style) do
    GenServer.call(server, {:set_style, style})
  end

  def save_position(server \\ __MODULE__) do
    GenServer.call(server, :save_position)
  end

  def restore_position(server \\ __MODULE__) do
    GenServer.call(server, :restore_position)
  end

  def get_position(server \\ __MODULE__) do
    GenServer.call(server, :get_position)
  end

  ## Manager-specific handlers

  @impl Raxol.Core.Behaviours.BaseManager
  def handle_manager_call({:move_to, row, col}, _from, state) do
    new_position = {row, col}

    new_state = %{
      state
      | row: row,
        col: col,
        position: new_position,
        history:
          add_to_history(state.history, new_position, state.history_limit)
    }

    {:reply, :ok, new_state}
  end

  def handle_manager_call({:set_visibility, visible}, _from, state) do
    new_state = %{state | visible: visible}
    {:reply, :ok, new_state}
  end

  def handle_manager_call({:set_style, style}, _from, state) do
    new_state = %{state | style: style}
    {:reply, :ok, new_state}
  end

  def handle_manager_call(:save_position, _from, state) do
    new_state = %{
      state
      | saved_row: state.row,
        saved_col: state.col,
        saved_position: state.position,
        saved_style: state.style,
        saved_visible: state.visible,
        saved_blinking: state.blinking,
        saved_color: state.color
    }

    {:reply, :ok, new_state}
  end

  def handle_manager_call(:restore_position, _from, state) do
    case state.saved_position do
      nil ->
        {:reply, {:error, :no_saved_position}, state}

      {row, col} ->
        new_state = %{
          state
          | row: row,
            col: col,
            position: {row, col},
            style: state.saved_style || state.style,
            visible: state.saved_visible || state.visible,
            blinking: state.saved_blinking || state.blinking,
            color: state.saved_color || state.color
        }

        {:reply, :ok, new_state}
    end
  end

  def handle_manager_call(:get_position, _from, state) do
    {:reply, {state.row, state.col}, state}
  end

  @impl Raxol.Core.Behaviours.BaseManager
  def handle_manager_info(:blink_tick, state) do
    new_state =
      case state.state do
        :visible -> %{state | state: :hidden}
        :hidden -> %{state | state: :visible}
      end

    {:noreply, new_state}
  end

  ## Private Functions

  defp add_to_history(history, position, limit) do
    new_history = [position | history]

    if length(new_history) > limit do
      Enum.take(new_history, limit)
    else
      new_history
    end
  end
end
