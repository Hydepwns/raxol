defmodule Raxol.Terminal.ANSI.MouseEvents do
  @moduledoc """
  Handles mouse event reporting for the terminal emulator.
  Supports various mouse reporting modes including:
  - Basic mouse tracking (mode 1000)
  - Highlight mouse tracking (mode 1001)
  - Cell mouse tracking (mode 1002)
  - All mouse tracking (mode 1003)
  - Focus events (mode 1004)
  - UTF-8 mouse reporting (mode 1005)
  - SGR mouse reporting (mode 1006)
  - URXVT mouse reporting (mode 1015)
  - SGR pixels mouse reporting (mode 1016)
  """

  import Bitwise

  @type mouse_mode ::
          :basic
          | :highlight
          | :cell
          | :all
          | :focus
          | :utf8
          | :sgr
          | :urxvt
          | :sgr_pixels

  @type mouse_state :: %{
          enabled: boolean(),
          mode: mouse_mode(),
          button_state: :none | :left | :middle | :right | :release,
          modifiers: MapSet.t(),
          position: {integer(), integer()},
          last_position: {integer(), integer()},
          drag_state: :none | :dragging | :drag_end
        }

  @type modifier :: :shift | :alt | :ctrl | :meta

  # Cache button codes to avoid repeated calculations
  @button_codes %{
    none: "0",
    left: "1",
    middle: "2",
    right: "3",
    release: "0",
    scroll_up: "64",
    scroll_down: "65"
  }

  @sgr_button_codes %{
    none: "0",
    left: "0",
    middle: "1",
    right: "2",
    release: "3",
    scroll_up: "64",
    scroll_down: "65"
  }

  defp button_to_code(button_state) do
    Map.get(@button_codes, button_state, "0")
  end

  defp sgr_button_to_code(button_state) do
    Map.get(@sgr_button_codes, button_state, "0")
  end

  def generate_basic_report(state) do
    # Format: \e[M<button><x><y>
    # Button: 0=release, 1=left, 2=middle, 3=right, 64=scroll up, 65=scroll down
    # x, y: 1-based coordinates
    {x, y} = state.position
    button_code = button_to_code(state.button_state)
    "\e[M#{button_code}#{x + 32}#{y + 32}"
  end

  def generate_highlight_report(state) do
    # Highlight mouse tracking (mode 1001)
    # Similar to basic but with highlighting
    generate_basic_report(state)
  end

  def generate_cell_report(state) do
    # Cell mouse tracking (mode 1002)
    # Reports cell changes
    generate_basic_report(state)
  end

  def generate_all_report(state) do
    # All mouse tracking (mode 1003)
    # Reports all mouse events
    generate_basic_report(state)
  end

  def generate_focus_report(state) do
    # Format: \e[I for focus in, \e[O for focus out
    case state.button_state do
      :focus_in -> "\e[I"
      :focus_out -> "\e[O"
      _ -> ""
    end
  end

  def generate_utf8_report(state) do
    {x, y} = state.position
    button_code = button_to_code(state.button_state)
    :erlang.binary_to_list(<<27, "M", button_code, x + 32, y + 32>>)
  end

  def generate_sgr_report(state) do
    {x, y} = state.position
    button_code = sgr_button_to_code(state.button_state)
    :erlang.binary_to_list(<<27, "[<", button_code, ";", x, ";", y, "M">>)
  end

  def generate_urxvt_report(state) do
    # Reuse SGR report format for URXVT
    generate_sgr_report(state)
  end

  def generate_sgr_pixels_report(state) do
    # Optimize SGR pixels mouse reporting by using binary concatenation
    {x, y} = state.position
    button_code = sgr_button_to_code(state.button_state)
    :erlang.binary_to_list(<<27, "[<", button_code, ";", x, ";", y, "M">>)
  end

  # @report_generators %{
  #   basic: &generate_basic_report/1,
  #   highlight: &generate_highlight_report/1,
  #   cell: &generate_cell_report/1,
  #   all: &generate_all_report/1,
  #   focus: &generate_focus_report/1,
  #   utf8: &generate_utf8_report/1,
  #   sgr: &generate_sgr_report/1,
  #   urxvt: &generate_urxvt_report/1,
  #   sgr_pixels: &generate_sgr_pixels_report/1
  # }

  @doc """
  Creates a new mouse state with default values.
  """
  @spec new() :: mouse_state()
  def new do
    %{
      enabled: false,
      mode: :basic,
      button_state: :none,
      modifiers: MapSet.new(),
      position: {0, 0},
      last_position: {0, 0},
      drag_state: :none
    }
  end

  @doc """
  Enables mouse tracking with the specified mode.
  """
  @spec enable(mouse_state(), mouse_mode()) :: mouse_state()
  def enable(state, mode) do
    %{state | enabled: true, mode: mode}
  end

  @doc """
  Disables mouse tracking.
  """
  @spec disable(mouse_state()) :: mouse_state()
  def disable(state) do
    %{state | enabled: false}
  end

  @doc """
  Updates the mouse position.
  """
  @spec update_position(mouse_state(), {integer(), integer()}) :: mouse_state()
  def update_position(state, position) do
    %{state | last_position: state.position, position: position}
  end

  @doc """
  Updates the button state.
  """
  @spec update_button_state(
          mouse_state(),
          :none | :left | :middle | :right | :release
        ) :: mouse_state()
  def update_button_state(state, button_state) do
    %{state | button_state: button_state}
  end

  @doc """
  Updates the modifiers state.
  """
  @spec update_modifiers(mouse_state(), MapSet.t()) :: mouse_state()
  def update_modifiers(state, modifiers) do
    %{state | modifiers: modifiers}
  end

  @doc """
  Updates the drag state.
  """
  @spec update_drag_state(mouse_state(), :none | :dragging | :drag_end) ::
          mouse_state()
  def update_drag_state(state, drag_state) do
    %{state | drag_state: drag_state}
  end

  @doc """
  Generates a mouse event report based on the current state.
  """
  @spec generate_report(mouse_state()) :: String.t()
  def generate_report(%{mode: :basic} = state), do: generate_basic_report(state)

  def generate_report(%{mode: :highlight} = state),
    do: generate_highlight_report(state)

  def generate_report(%{mode: :cell} = state), do: generate_cell_report(state)
  def generate_report(%{mode: :all} = state), do: generate_all_report(state)
  def generate_report(%{mode: :focus} = state), do: generate_focus_report(state)
  def generate_report(%{mode: :utf8} = state), do: generate_utf8_report(state)
  def generate_report(%{mode: :sgr} = state), do: generate_sgr_report(state)
  def generate_report(%{mode: :urxvt} = state), do: generate_urxvt_report(state)

  def generate_report(%{mode: :sgr_pixels} = state),
    do: generate_sgr_pixels_report(state)

  def generate_report(state), do: generate_basic_report(state)

  @doc """
  Processes a mouse event and returns the updated state and event data.
  Supports extended mouse reporting modes including SGR pixels and URXVT.
  """
  @spec process_event(mouse_state(), binary()) :: {mouse_state(), map()}
  def process_event(state, <<"\e[M", button, x, y>>)
      when state.mode == :basic do
    {new_state, event} = process_basic_event(state, button, x - 32, y - 32)
    {new_state, event}
  end

  def process_event(state, <<"\e[", rest::binary>>) when state.mode == :sgr do
    case parse_mouse_event(rest) do
      {:ok, event_data} ->
        {update_state(state, event_data), event_data}

      :error ->
        {state, %{type: :error, message: "Invalid SGR mouse event"}}
    end
  end

  def process_event(state, <<"\e[", rest::binary>>) when state.mode == :urxvt do
    case parse_urxvt_event(rest) do
      {:ok, event_data} ->
        {update_state(state, event_data), event_data}

      :error ->
        {state, %{type: :error, message: "Invalid URXVT mouse event"}}
    end
  end

  def process_event(state, <<"\e[", rest::binary>>)
      when state.mode == :sgr_pixels do
    case parse_sgr_pixels_event(rest) do
      {:ok, event_data} ->
        {update_state(state, event_data), event_data}

      :error ->
        {state, %{type: :error, message: "Invalid SGR pixels mouse event"}}
    end
  end

  @doc """
  Parses a mouse event in the format: <button>;<x>;<y>M
  """
  @spec parse_mouse_event(binary()) ::
          {:ok,
           %{
             type: :mouse,
             button: atom(),
             modifiers: MapSet.t(),
             position: {integer(), integer()},
             mode: :sgr
           }}
          | :error
  def parse_mouse_event(<<button, ";", rest::binary>>) do
    case parse_coordinates(rest) do
      {:ok, {x, y}} ->
        {:ok,
         %{
           type: :mouse,
           button: decode_button(button),
           modifiers: decode_modifiers(button),
           position: {x, y},
           mode: :sgr
         }}

      _ ->
        :error
    end
  end

  @doc """
  Parses a URXVT mouse event in the format: <button>;<x>;<y>M
  """
  @spec parse_urxvt_event(binary()) ::
          {:ok,
           %{
             type: :mouse,
             button: atom(),
             modifiers: MapSet.t(),
             position: {integer(), integer()},
             mode: :urxvt
           }}
          | :error
  def parse_urxvt_event(<<button, ";", rest::binary>>) do
    case parse_coordinates(rest) do
      {:ok, {x, y}} ->
        {:ok,
         %{
           type: :mouse,
           button: decode_urxvt_button(button),
           modifiers: decode_modifiers(button),
           position: {x, y},
           mode: :urxvt
         }}

      _ ->
        :error
    end
  end

  @doc """
  Parses an SGR pixels mouse event in the format: <button>;<x>;<y>M
  """
  @spec parse_sgr_pixels_event(binary()) ::
          {:ok,
           %{
             type: :mouse,
             button: atom(),
             modifiers: MapSet.t(),
             position: {integer(), integer()},
             mode: :sgr_pixels
           }}
          | :error
  def parse_sgr_pixels_event(<<button, ";", rest::binary>>) do
    case parse_coordinates(rest) do
      {:ok, {x, y}} ->
        {:ok,
         %{
           type: :mouse,
           button: decode_button(button),
           modifiers: decode_modifiers(button),
           position: {x, y},
           mode: :sgr_pixels
         }}

      _ ->
        :error
    end
  end

  @doc """
  Decodes button state and modifiers from a mouse event byte.
  """
  @spec decode_button(integer()) :: :left | :middle | :right | :release
  def decode_button(button) do
    case button &&& 0x3 do
      0 -> :release
      1 -> :left
      2 -> :middle
      3 -> :right
    end
  end

  @doc """
  Decodes modifier keys from a mouse event byte.
  """
  @spec decode_modifiers(integer()) :: MapSet.t(modifier())
  def decode_modifiers(button) do
    modifiers = MapSet.new()

    modifiers =
      if (button &&& 0x4) != 0,
        do: MapSet.put(modifiers, :shift),
        else: modifiers

    modifiers =
      if (button &&& 0x8) != 0,
        do: MapSet.put(modifiers, :alt),
        else: modifiers

    modifiers =
      if (button &&& 0x10) != 0,
        do: MapSet.put(modifiers, :ctrl),
        else: modifiers

    modifiers =
      if (button &&& 0x20) != 0,
        do: MapSet.put(modifiers, :meta),
        else: modifiers

    modifiers
  end

  @doc """
  Decodes URXVT button state from a mouse event byte.
  """
  @spec decode_urxvt_button(integer()) :: :left | :middle | :right | :release
  def decode_urxvt_button(button) do
    case button &&& 0x3 do
      0 -> :release
      1 -> :left
      2 -> :middle
      3 -> :right
    end
  end

  @doc """
  Parses coordinates from a mouse event string.
  """
  @spec parse_coordinates(binary()) :: {:ok, {integer(), integer()}} | :error
  def parse_coordinates(rest) do
    case String.split(rest, ";", parts: 2) do
      [x_str, y_str] ->
        with {x, ""} <- Integer.parse(x_str),
             {y, ""} <- Integer.parse(y_str) do
          {:ok, {x, y}}
        else
          _ -> :error
        end

      _ ->
        :error
    end
  end

  @doc """
  Updates the mouse state with new event data.
  """
  @spec update_state(mouse_state(), map()) :: mouse_state()
  def update_state(state, event) do
    %{
      state
      | button_state: event.button,
        modifiers: event.modifiers,
        last_position: state.position,
        position: event.position,
        drag_state: calculate_drag_state(state, event)
    }
  end

  @doc """
  Calculates the drag state based on the current and previous mouse states.
  """
  @spec calculate_drag_state(mouse_state(), map()) ::
          :none | :dragging | :drag_end
  def calculate_drag_state(state, event) do
    cond do
      event.button == :release ->
        :drag_end

      state.button_state != :none and event.button != :none ->
        :dragging

      true ->
        :none
    end
  end

  @spec process_basic_event(mouse_state(), integer(), integer(), integer()) ::
          {mouse_state(), map()}
  defp process_basic_event(state, button, x, y) do
    event_data = %{
      type: :mouse,
      button: decode_button(button),
      modifiers: decode_modifiers(button),
      x: x,
      y: y
    }

    {state, event_data}
  end
end
