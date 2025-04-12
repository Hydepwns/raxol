defmodule Raxol.Terminal.ANSI.WindowManipulation do
  @moduledoc """
  Handles window manipulation sequences for the terminal emulator.
  Supports various window operations including:
  - Window size queries and reports
  - Window position queries and reports
  - Window title manipulation
  - Window icon manipulation
  - Window stacking order
  """

  @type window_state :: %{
          title: String.t(),
          icon_name: String.t(),
          size: {integer(), integer()},
          position: {integer(), integer()},
          stacking_order: :normal | :above | :below
        }

  @doc """
  Creates a new window state with default values.
  """
  @spec new() :: window_state()
  def new do
    %{
      title: "",
      icon_name: "",
      size: {80, 24},
      position: {0, 0},
      stacking_order: :normal
    }
  end

  @doc """
  Processes a window manipulation sequence and returns the updated state and response.
  """
  @spec process_sequence(window_state(), binary()) :: {window_state(), binary()}
  def process_sequence(state, <<"\e[", _rest::binary>>) do
    # Window manipulation parsing is currently incomplete and returns :error.
    # Simply return the state until parsing is fixed.
    # case parse_sequence(rest) do
    #  {:ok, operation, params} ->
    #    handle_operation(state, operation, params)
    #  :error ->
    #    {state, ""}
    # end
    # Return empty binary as no response is generated
    {state, ""}
  end

  @doc """
  Parses a window manipulation sequence.
  """
  @spec parse_sequence(binary()) :: {:ok, atom(), list(integer())} | :error
  def parse_sequence(<<params::binary-size(1), operation::binary>>) do
    case parse_params(params) do
      {:ok, parsed_params} ->
        {:ok, decode_operation(operation), parsed_params}

      :error ->
        :error
    end
  end

  def parse_sequence(_), do: :error

  @doc """
  Parses parameters from a window manipulation sequence.
  """
  @spec parse_params(binary()) :: {:ok, list(integer())} | :error
  def parse_params(params) do
    case String.split(params, ";", trim: true) do
      [] ->
        {:ok, []}

      param_strings ->
        case Enum.map(param_strings, &Integer.parse/1) do
          list when length(list) == length(param_strings) ->
            {:ok, Enum.map(list, fn {num, _} -> num end)}

          _ ->
            :error
        end
    end
  end

  @doc """
  Decodes a window manipulation operation from its character code.
  """
  @spec decode_operation(integer()) :: atom()
  def decode_operation(?t), do: :move
  def decode_operation(?T), do: :move_relative
  def decode_operation(?@), do: :resize
  def decode_operation(?A), do: :resize_relative
  def decode_operation(?l), do: :maximize
  def decode_operation(?L), do: :restore
  def decode_operation(?i), do: :raise
  def decode_operation(?I), do: :lower
  def decode_operation(?s), do: :stack_above
  def decode_operation(?S), do: :stack_below
  def decode_operation(?w), do: :set_title
  def decode_operation(?j), do: :set_icon
  def decode_operation(?q), do: :query
  def decode_operation(_), do: :unknown

  @doc """
  Handles a window manipulation operation and returns the updated state and response.
  """
  @spec handle_operation(window_state(), atom(), list(integer())) ::
          {window_state(), binary()}
  def handle_operation(state, :move, [x, y]) do
    {%{state | position: {x, y}}, ""}
  end

  def handle_operation(state, :move_relative, [dx, dy]) do
    {x, y} = state.position
    {%{state | position: {x + dx, y + dy}}, ""}
  end

  def handle_operation(state, :resize, [width, height]) do
    {%{state | size: {width, height}}, ""}
  end

  def handle_operation(state, :resize_relative, [dw, dh]) do
    {w, h} = state.size
    {%{state | size: {w + dw, h + dh}}, ""}
  end

  def handle_operation(state, :maximize, _) do
    {%{state | size: {9999, 9999}}, ""}
  end

  def handle_operation(state, :restore, _) do
    {%{state | size: {80, 24}}, ""}
  end

  def handle_operation(state, :raise, _) do
    {%{state | stacking_order: :above}, ""}
  end

  def handle_operation(state, :lower, _) do
    {%{state | stacking_order: :below}, ""}
  end

  def handle_operation(state, :stack_above, _) do
    {%{state | stacking_order: :above}, ""}
  end

  def handle_operation(state, :stack_below, _) do
    {%{state | stacking_order: :below}, ""}
  end

  def handle_operation(state, :set_title, []) do
    {state, ""}
  end

  def handle_operation(state, :set_title, title) when is_list(title) do
    title_str = Enum.map_join(title, "", &<<&1>>)
    {%{state | title: title_str}, ""}
  end

  def handle_operation(state, :set_icon, []) do
    {state, ""}
  end

  def handle_operation(state, :set_icon, icon) when is_list(icon) do
    icon_str = Enum.map_join(icon, "", &<<&1>>)
    {%{state | icon_name: icon_str}, ""}
  end

  def handle_operation(state, :query, []) do
    {w, h} = state.size
    {x, y} = state.position
    response = "\e[8;#{h};#{w}t\e[3;#{x};#{y}t"
    {state, response}
  end

  def handle_operation(state, :unknown, _) do
    {state, ""}
  end
end
