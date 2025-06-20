defmodule Raxol.Terminal.ANSI.MouseTracking do
  @moduledoc """
  Handles mouse tracking and focus tracking for the terminal.
  Supports various mouse tracking modes and focus tracking events.
  """

  import Bitwise
  alias Raxol.Terminal.ANSI.Monitor

  @type mouse_button :: :left | :middle | :right | :wheel_up | :wheel_down
  @type mouse_action :: :press | :release | :move | :drag
  @type mouse_event :: {mouse_button(), mouse_action(), integer(), integer()}
  @type focus_event :: :focus_in | :focus_out

  @mouse_modes %{
    normal: 1000,
    highlight: 1001,
    button: 1002,
    any: 1003,
    focus: 1004
  }

  @mouse_buttons %{
    0 => :left,
    1 => :middle,
    2 => :right,
    64 => :wheel_up,
    65 => :wheel_down,
    66 => :wheel_up
  }

  @mouse_actions %{
    0 => :press,
    3 => :release,
    32 => :move,
    35 => :drag,
    240 => :wheel_up,
    243 => :wheel_down
  }

  @doc """
  Enables mouse tracking with the specified mode.
  """
  @spec enable_mouse_tracking(atom()) :: String.t()
  def enable_mouse_tracking(mode) do
    case Map.get(@mouse_modes, mode) do
      nil ->
        Monitor.record_error(
          "",
          "Invalid mouse tracking mode: #{inspect(mode)}",
          %{mode: mode}
        )

        ""

      code ->
        "\e[?#{code}h"
    end
  end

  @doc """
  Disables mouse tracking with the specified mode.
  """
  @spec disable_mouse_tracking(atom()) :: String.t()
  def disable_mouse_tracking(mode) do
    case Map.get(@mouse_modes, mode) do
      nil ->
        Monitor.record_error(
          "",
          "Invalid mouse tracking mode: #{inspect(mode)}",
          %{mode: mode}
        )

        ""

      code ->
        "\e[?#{code}l"
    end
  end

  @doc """
  Parses a mouse tracking sequence into a mouse event.
  """
  @spec parse_mouse_sequence(String.t()) :: mouse_event() | nil
  def parse_mouse_sequence(sequence) do
    try do
      IO.puts(
        "parse_mouse_sequence: sequence=#{inspect(sequence)}, bytes=#{inspect(:erlang.binary_to_list(sequence))}"
      )

      case sequence do
        <<"\e[M", button, x, y>> ->
          b = button - 32
          xx = x - 32
          yy = y - 32

          IO.puts(
            "parse_mouse_sequence: b=#{inspect(b)}, xx=#{inspect(xx)}, yy=#{inspect(yy)}"
          )

          parse_mouse_event(b, xx, yy)

        <<"\e[<", rest::binary>> ->
          parse_sgr_mouse_event(rest)

        _ ->
          nil
      end
    rescue
      e ->
        Monitor.record_error("", "Mouse sequence parse error: #{inspect(e)}", %{
          sequence: sequence,
          stacktrace: Exception.format_stacktrace(__STACKTRACE__)
        })

        nil
    end
  end

  @doc """
  Parses a focus tracking sequence into a focus event.
  """
  @spec parse_focus_sequence(String.t()) :: focus_event() | nil
  def parse_focus_sequence(sequence) do
    try do
      case sequence do
        "\e[I" -> :focus_in
        "\e[O" -> :focus_out
        _ -> nil
      end
    rescue
      e ->
        Monitor.record_error("", "Focus sequence parse error: #{inspect(e)}", %{
          sequence: sequence,
          stacktrace: Exception.format_stacktrace(__STACKTRACE__)
        })

        nil
    end
  end

  @doc """
  Formats a mouse event into a tracking sequence.
  """
  @spec format_mouse_event(mouse_event()) :: String.t()
  def format_mouse_event({button, action, x, y}) do
    button_code = get_button_code(button)
    action_code = get_action_code(action)
    "\e[M#{button_code + action_code}#{x + 32}#{y + 32}"
  end

  @doc """
  Formats a focus event into a tracking sequence.
  """
  @spec format_focus_event(focus_event()) :: String.t()
  def format_focus_event(:focus_in), do: "\e[I"
  def format_focus_event(:focus_out), do: "\e[O"

  defp parse_mouse_event(0, x, y), do: {:left, :press, x, y}
  defp parse_mouse_event(1, x, y), do: {:middle, :press, x, y}
  defp parse_mouse_event(2, x, y), do: {:right, :press, x, y}
  defp parse_mouse_event(3, x, y), do: {:left, :release, x, y}
  defp parse_mouse_event(32, x, y), do: {:left, :move, x, y}
  defp parse_mouse_event(35, x, y), do: {:left, :drag, x, y}

  defp parse_mouse_event(button_code, x, y),
    do: parse_mouse_event_fallback(button_code, x, y)

  defp parse_mouse_event_fallback(button_code, x, y) do
    import Bitwise
    button = Map.get(@mouse_buttons, button_code &&& 0x03)
    action = Map.get(@mouse_actions, button_code)
    if button && action, do: {button, action, x, y}, else: nil
  end

  defp parse_sgr_mouse_event(rest) do
    rest_str =
      if is_binary(rest),
        do: :erlang.binary_to_list(rest) |> to_string(),
        else: rest

    case Regex.run(~r/^([0-9]+);([0-9]+);([0-9]+)([mM])/, rest_str) do
      [_, button, x, y, kind] ->
        button = String.to_integer(button)
        x = String.to_integer(x)
        y = String.to_integer(y)
        event = parse_mouse_event(button, x, y)
        if kind == "m" and event, do: put_elem(event, 1, :release), else: event

      _ ->
        nil
    end
  end

  defp get_button_code(button) do
    Enum.find_value(@mouse_buttons, 0, fn {code, b} ->
      if b == button, do: code
    end)
  end

  defp get_action_code(action) do
    Enum.find_value(@mouse_actions, 0, fn {code, a} ->
      if a == action, do: code
    end)
  end
end
