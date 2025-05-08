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

  alias Raxol.Terminal.ANSI.SequenceParser
  require Logger

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
  Handles CSI (\e[...t) and OSC (\e]...\a or \e]...\e\\) sequences.
  """
  @spec process_sequence(window_state(), binary()) :: {window_state(), binary()}
  def process_sequence(state, <<"\e[", rest::binary>>) do
    # Attempt to parse CSI sequences, focusing on those ending in 't'
    case Regex.run(~r/^([0-9;]*)([a-zA-Z])$/, rest, capture: :all_but_first) do
      # Match only if final byte is 't'
      [param_string, <<?t>>] ->
        case SequenceParser.parse_params(param_string) do
          {:ok, params} ->
            handle_csi_operation(state, params)

          :error ->
            Logger.debug(
              "[WindowManipulation] Failed to parse CSI 't' params: #{param_string}"
            )

            {state, ""}
        end

      [_param_string, _other_final_byte] ->
        # Ignore CSI sequences not ending in 't'
        {state, ""}

      # Regex didn't match
      nil ->
        Logger.debug(
          "[WindowManipulation] Invalid CSI sequence format: \e[#{rest}"
        )

        {state, ""}
    end
  end

  def process_sequence(state, <<"\e]", rest::binary>>) do
    # Handle OSC sequences (e.g., \e]Ps;Pt\a or \e]Ps;Pt\e\\)
    case String.split(rest, ["\a", "\e\\"], parts: 2) do
      [osc_content] ->
        handle_osc_content(state, osc_content)

      [osc_content, _rest] ->
        handle_osc_content(state, osc_content)

      _ ->
        Logger.debug(
          "[WindowManipulation] Unhandled OSC sequence format: \e]#{rest}"
        )

        {state, ""}
    end
  end

  def process_sequence(state, _unhandled_sequence) do
    # Ignore sequences not starting with \e[ or \e]
    {state, ""}
  end

  # --- Private CSI Handler --- #

  @spec handle_csi_operation(window_state(), list(integer())) ::
          {window_state(), binary()}
  defp handle_csi_operation(state, params) do
    case params do
      # Move window to x, y (Corrected Parameter Order: CSI 3 ; x ; y t)
      [3, x, y] ->
        handle_operation(state, :move, [x, y])

      # Resize window to height, width (Params: Height;Width -> Call: width, height)
      [8, h, w] ->
        handle_operation(state, :resize, [w, h])

      # Maximize window
      [9, 1] ->
        handle_operation(state, :maximize, [])

      # Restore window size
      [9, 0] ->
        handle_operation(state, :restore, [])

      # Report window state (size and position)
      # Query Size & Position
      [13] ->
        handle_operation(state, :query, [])

      # Query Size & Position (Alternative)
      [14] ->
        handle_operation(state, :query, [])

      # Query Size only
      [18] ->
        handle_operation(state, :query_size, [])

      # Query Screen Size
      [19] ->
        handle_operation(state, :query_screen_size, [])

      # Add handlers for Raise (5) and Lower (6)
      [5] ->
        handle_operation(state, :raise, [])

      [6] ->
        handle_operation(state, :lower, [])

      _ ->
        Logger.debug(
          "[WindowManipulation] Unhandled CSI 't' operation with params: #{inspect(params)}"
        )

        {state, ""}
    end
  end

  # --- Private OSC Handler --- #

  defp handle_osc_content(state, osc_content) do
    case String.split(osc_content, ";", parts: 2) do
      [ps_str, pt] when ps_str != "" ->
        case Integer.parse(ps_str) do
          {ps_int, ""} ->
            handle_osc_operation(state, ps_int, pt)

          _ ->
            Logger.debug(
              "[WindowManipulation] Invalid OSC Ps parameter: #{ps_str}"
            )

            {state, ""}
        end

      _ ->
        Logger.debug("[WindowManipulation] Invalid OSC format: #{osc_content}")
        {state, ""}
    end
  end

  @spec handle_osc_operation(window_state(), integer(), String.t()) ::
          {window_state(), binary()}
  defp handle_osc_operation(state, 0, pt) do
    # Set icon name and window title
    {new_state, _} = handle_operation(state, :set_icon, pt)
    handle_operation(new_state, :set_title, pt)
  end

  defp handle_osc_operation(state, 1, pt) do
    # Set icon name
    handle_operation(state, :set_icon, pt)
  end

  defp handle_osc_operation(state, 2, pt) do
    # Set window title
    handle_operation(state, :set_title, pt)
  end

  defp handle_osc_operation(state, _ps, _pt) do
    # Ignore other OSC codes for now
    {state, ""}
  end

  # --- Operation Handlers (modified) --- #

  @spec handle_operation(window_state(), atom(), list() | String.t()) ::
          {window_state(), binary()}
  def handle_operation(state, :move, [x, y])
      when is_integer(x) and is_integer(y) do
    # Explicitly return the updated state map
    {%{state | position: {x, y}}, ""}
  end

  def handle_operation(state, :resize, [width, height])
      when is_integer(width) and is_integer(height) do
    # Explicitly return the updated state map
    {%{state | size: {width, height}}, ""}
  end

  def handle_operation(state, :maximize, _) do
    updated_state = %{state | size: {100, 50}}
    {updated_state, ""}
  end

  def handle_operation(state, :restore, _) do
    updated_state = %{state | size: {80, 24}}
    {updated_state, ""}
  end

  def handle_operation(state, :raise, _) do
    updated_state = %{state | stacking_order: :above}
    {updated_state, ""}
  end

  def handle_operation(state, :lower, _) do
    updated_state = %{state | stacking_order: :below}
    {updated_state, ""}
  end

  def handle_operation(state, :set_title, title) when is_binary(title) do
    {%{state | title: title}, ""}
  end

  def handle_operation(state, :set_icon, icon_name) when is_binary(icon_name) do
    {%{state | icon_name: icon_name}, ""}
  end

  # Handle Query operations
  def handle_operation(state, :query, _) do
    {w, h} = state.size
    {x, y} = state.position
    # Corrected Response format: CSI 8 ; h ; w t THEN CSI 3 ; x ; y t
    # Swapped x and y in the position report part
    response = "\e[8;#{h};#{w}t\e[3;#{y};#{x}t"
    # Return the original state and the response
    {state, response}
  end

  def handle_operation(state, :query_size, _) do
    # Report size only (CSI 18 t)
    {w, h} = state.size
    # Response format: CSI 8 ; h ; w t
    response = "\e[8;#{h};#{w}t"
    {state, response}
  end

  def handle_operation(state, :query_screen_size, _) do
    # Report screen size in pixels (often fixed in emulators)
    # Placeholder response
    # Example: Height=1024, Width=768
    response = "\e[9;1024;768t"
    {state, response}
  end

  # Catch-all for unhandled operations or incorrect params
  def handle_operation(state, op, params) do
    Logger.debug(
      "[WindowManipulation] Unhandled operation :#{op} with params #{inspect(params)}"
    )

    {state, ""}
  end

  # Remove obsolete private functions:
  # - parse_sequence/1
  # - parse_csi_t_params/1
  # - decode_operation/1
end
