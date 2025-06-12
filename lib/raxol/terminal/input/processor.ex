defmodule Raxol.Terminal.Input.Processor do
  @moduledoc """
  Advanced input processing for the terminal emulator.
  Handles mouse events, keyboard modifiers, and input sequences.
  """

  alias Raxol.Terminal.Input.Event
  alias Raxol.Terminal.Input.Event.MouseEvent
  alias Raxol.Terminal.Input.Event.KeyEvent

  @type mouse_button :: :left | :middle | :right | :wheel_up | :wheel_down
  @type mouse_action :: :press | :release | :drag | :move
  @type modifier :: :shift | :ctrl | :alt | :meta
  @type input_sequence :: String.t()

  @doc """
  Processes raw input data into structured events.
  """
  @spec process_input(String.t()) :: {:ok, Event.t()} | {:error, term()}
  def process_input(data) when is_binary(data) do
    case parse_input(data) do
      {:ok, event} -> {:ok, event}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Parses mouse event sequences.
  """
  @spec parse_mouse_event(String.t()) :: {:ok, MouseEvent.t()} | {:error, term()}
  def parse_mouse_event(<<?[, rest::binary>>) do
    case parse_mouse_sequence(rest) do
      {:ok, event} -> {:ok, event}
      {:error, reason} -> {:error, reason}
    end
  end
  def parse_mouse_event(_), do: {:error, :invalid_mouse_event}

  @doc """
  Parses keyboard event sequences.
  """
  @spec parse_key_event(String.t()) :: {:ok, KeyEvent.t()} | {:error, term()}
  def parse_key_event(<<?[, rest::binary>>) do
    case parse_key_sequence(rest) do
      {:ok, event} -> {:ok, event}
      {:error, reason} -> {:error, reason}
    end
  end
  def parse_key_event(<<char::utf8>>) when char > 0 do
    {:ok, %KeyEvent{key: <<char::utf8>>, modifiers: []}}
  end
  def parse_key_event(_), do: {:error, :invalid_key_event}

  @doc """
  Formats a mouse event into a terminal sequence.
  """
  @spec format_mouse_event(MouseEvent.t()) :: String.t()
  def format_mouse_event(%MouseEvent{} = event) do
    button_code = encode_mouse_button(event.button)
    action_code = encode_mouse_action(event.action)
    modifiers = encode_modifiers(event.modifiers)

    "\e[#{action_code};#{button_code};#{event.x};#{event.y}#{modifiers}M"
  end

  @doc """
  Formats a key event into a terminal sequence.
  """
  @spec format_key_event(KeyEvent.t()) :: String.t()
  def format_key_event(%KeyEvent{} = event) do
    case event.key do
      <<char::utf8>> when char < 128 ->
        modifiers = encode_modifiers(event.modifiers)
        if modifiers != "", do: "\e[#{modifiers}#{event.key}", else: event.key
      _ ->
        "\e[#{event.key}"
    end
  end

  # Private functions

  defp parse_input(<<?\e, rest::binary>>) do
    case rest do
      <<?[, rest::binary>> ->
        case parse_sequence(rest) do
          {:ok, event} -> {:ok, event}
          {:error, reason} -> {:error, reason}
        end
      _ ->
        {:error, :invalid_escape_sequence}
    end
  end
  defp parse_input(<<char::utf8>>) when char > 0 do
    {:ok, %KeyEvent{key: <<char::utf8>>, modifiers: []}}
  end
  defp parse_input(_), do: {:error, :invalid_input}

  defp parse_sequence(<<?M, rest::binary>>) do
    parse_mouse_sequence(rest)
  end
  defp parse_sequence(rest) do
    parse_key_sequence(rest)
  end

  defp parse_mouse_sequence(<<action::binary-size(1), button::binary-size(1), ?;, x::binary-size(1), ?;, y::binary-size(1), modifiers::binary>>) do
    with {:ok, action} <- decode_mouse_action(action),
         {:ok, button} <- decode_mouse_button(button),
         {x, ""} <- Integer.parse(x),
         {y, ""} <- Integer.parse(y),
         {:ok, modifiers} <- decode_modifiers(modifiers) do
      {:ok, %MouseEvent{
        action: action,
        button: button,
        x: x,
        y: y,
        modifiers: modifiers,
        timestamp: System.monotonic_time()
      }}
    else
      _ -> {:error, :invalid_mouse_sequence}
    end
  end
  defp parse_mouse_sequence(_), do: {:error, :invalid_mouse_sequence}

  defp parse_key_sequence(sequence) do
    case String.split(sequence, ";") do
      [key] ->
        {:ok, %KeyEvent{key: key, modifiers: []}}
      [modifiers, key] ->
        case decode_modifiers(modifiers) do
          {:ok, mods} -> {:ok, %KeyEvent{key: key, modifiers: mods}}
          error -> error
        end
      _ ->
        {:error, :invalid_key_sequence}
    end
  end

  defp encode_mouse_button(:left), do: "0"
  defp encode_mouse_button(:middle), do: "1"
  defp encode_mouse_button(:right), do: "2"
  defp encode_mouse_button(:wheel_up), do: "64"
  defp encode_mouse_button(:wheel_down), do: "65"

  defp encode_mouse_action(:press), do: "0"
  defp encode_mouse_action(:release), do: "3"
  defp encode_mouse_action(:drag), do: "32"
  defp encode_mouse_action(:move), do: "35"

  defp encode_modifiers([]), do: ""
  defp encode_modifiers(modifiers) do
    modifier_codes = Enum.map(modifiers, &encode_modifier/1)
    Enum.join(modifier_codes, ";")
  end

  defp encode_modifier(:shift), do: "2"
  defp encode_modifier(:alt), do: "3"
  defp encode_modifier(:ctrl), do: "5"
  defp encode_modifier(:meta), do: "9"

  defp decode_mouse_button("0"), do: {:ok, :left}
  defp decode_mouse_button("1"), do: {:ok, :middle}
  defp decode_mouse_button("2"), do: {:ok, :right}
  defp decode_mouse_button("64"), do: {:ok, :wheel_up}
  defp decode_mouse_button("65"), do: {:ok, :wheel_down}
  defp decode_mouse_button(_), do: {:error, :invalid_mouse_button}

  defp decode_mouse_action("0"), do: {:ok, :press}
  defp decode_mouse_action("3"), do: {:ok, :release}
  defp decode_mouse_action("32"), do: {:ok, :drag}
  defp decode_mouse_action("35"), do: {:ok, :move}
  defp decode_mouse_action(_), do: {:error, :invalid_mouse_action}

  defp decode_modifiers(""), do: {:ok, []}
  defp decode_modifiers(modifiers) do
    case String.split(modifiers, ";") do
      mods when is_list(mods) ->
        decoded = Enum.map(mods, &decode_modifier/1)
        if Enum.all?(decoded, &(&1 != :error)) do
          {:ok, decoded}
        else
          {:error, :invalid_modifiers}
        end
      _ ->
        {:error, :invalid_modifiers}
    end
  end

  defp decode_modifier("2"), do: :shift
  defp decode_modifier("3"), do: :alt
  defp decode_modifier("5"), do: :ctrl
  defp decode_modifier("9"), do: :meta
  defp decode_modifier(_), do: :error
end
