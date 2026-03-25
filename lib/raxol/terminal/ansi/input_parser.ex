defmodule Raxol.Terminal.ANSI.InputParser do
  @moduledoc """
  Parses raw ANSI terminal input bytes into Raxol Event structs.

  Handles:
  - Arrow keys, Enter, Backspace, Tab, Escape
  - Function keys F1-F12 (SS3 and CSI variants)
  - Navigation keys (Home, End, Insert, Delete, PageUp, PageDown)
  - Modifier combos (Shift+Tab, Ctrl+Arrow, Alt+key, etc.)
  - Ctrl+A through Ctrl+Z
  - Mouse SGR and X10/normal mode events
  - Focus in/out events
  - Bracketed paste
  - Printable ASCII and UTF-8 characters
  """

  alias Raxol.Core.Events.Event

  import Bitwise

  @doc """
  Parses a binary of raw terminal input into a list of Event structs.

  Returns a list because a single read may contain multiple events
  (e.g., pasted text or buffered input).
  """
  @spec parse(binary()) :: [Event.t()]

  # --- CSI sequences: ESC [ ... ---

  # Arrow keys
  def parse(<<27, 91, 65>>), do: [key_event(:up)]
  def parse(<<27, 91, 66>>), do: [key_event(:down)]
  def parse(<<27, 91, 67>>), do: [key_event(:right)]
  def parse(<<27, 91, 68>>), do: [key_event(:left)]

  # Navigation keys (CSI letter variants)
  def parse(<<27, 91, 72>>), do: [key_event(:home)]
  def parse(<<27, 91, 70>>), do: [key_event(:end)]

  # Shift+Tab (backtab)
  def parse(<<27, 91, 90>>), do: [key_event(:tab, shift: true)]

  # Focus events
  def parse(<<27, 91, 73>>), do: [%Event{type: :focus, data: %{focused: true}}]
  def parse(<<27, 91, 79>>), do: [%Event{type: :focus, data: %{focused: false}}]

  # Bracketed paste
  def parse(<<27, 91, 50, 48, 48, 126, rest::binary>>) do
    # ESC [ 200 ~ marks paste start
    case :binary.split(rest, <<27, 91, 50, 48, 49, 126>>) do
      [pasted, remaining] ->
        [%Event{type: :paste, data: %{text: pasted}} | parse(remaining)]

      [_no_end] ->
        # Paste end not yet received, treat entire rest as pasted text
        [%Event{type: :paste, data: %{text: rest}}]
    end
  end

  # Mouse SGR mode: ESC [ < params M/m
  def parse(<<27, 91, 60, rest::binary>>) do
    parse_sgr_mouse(rest)
  end

  # Mouse X10/normal mode: ESC [ M <3 bytes>
  def parse(<<27, 91, 77, button, x, y>>) do
    parse_x10_mouse(button, x, y)
  end

  # Modified keys: ESC [ 1 ; <mod> <letter>
  def parse(<<27, 91, 49, 59, mod, letter>>)
      when letter in [65, 66, 67, 68, 70, 72, 80, 81, 82, 83] do
    {shift, alt, ctrl} = decode_modifier(mod - ?0)
    key = csi_letter_to_key(letter)
    [key_event(key, shift: shift, alt: alt, ctrl: ctrl)]
  end

  # CSI tilde sequences: ESC [ <number> ~
  def parse(<<27, 91, rest::binary>>) do
    parse_csi_tilde(rest)
  end

  # --- SS3 sequences: ESC O ... ---

  # F1-F4 SS3 variants
  def parse(<<27, 79, 80>>), do: [key_event(:f1)]
  def parse(<<27, 79, 81>>), do: [key_event(:f2)]
  def parse(<<27, 79, 82>>), do: [key_event(:f3)]
  def parse(<<27, 79, 83>>), do: [key_event(:f4)]

  # SS3 Home/End (some terminals)
  def parse(<<27, 79, 72>>), do: [key_event(:home)]
  def parse(<<27, 79, 70>>), do: [key_event(:end)]

  # --- Alt+key: ESC <char> (must come after ESC[ and ESC O) ---

  def parse(<<27, char>>) when char >= 32 and char <= 126 do
    [key_event(:char, char: <<char>>, alt: true)]
  end

  # --- Bare escape ---
  def parse(<<27>>), do: [key_event(:escape)]

  # --- Control characters ---
  # Enter (CR)
  def parse(<<13>>), do: [key_event(:enter)]
  # Linefeed (LF) - also treat as enter
  def parse(<<10>>), do: [key_event(:enter)]
  # Backspace
  def parse(<<127>>), do: [key_event(:backspace)]
  # Tab
  def parse(<<9>>), do: [key_event(:tab)]
  # Ctrl+Space / Null
  def parse(<<0>>), do: [key_event(:char, char: " ", ctrl: true)]

  # Ctrl+A through Ctrl+Z (bytes 1-26, excluding special cases above)
  # 1=Ctrl+A, 2=Ctrl+B, ..., 9=Tab, 10=LF(Enter), 13=CR(Enter), 26=Ctrl+Z
  def parse(<<byte>>) when byte >= 1 and byte <= 26 do
    char = <<byte + 96>>
    [key_event(:char, char: char, ctrl: true)]
  end

  # --- Printable ASCII ---
  def parse(<<char>>) when char >= 32 and char <= 126 do
    [key_event(:char, char: <<char>>)]
  end

  # --- Multi-byte UTF-8 ---
  def parse(data) when is_binary(data) do
    if String.valid?(data) and String.length(data) == 1 do
      [key_event(:char, char: data)]
    else
      []
    end
  end

  # --- CSI tilde sequence parser ---

  defp parse_csi_tilde(rest) do
    case parse_csi_params(rest) do
      # Simple: ESC [ <n> ~
      {[n], ?~} ->
        [key_event(tilde_key(n))]

      # Modified: ESC [ <n> ; <mod> ~
      {[n, mod], ?~} ->
        {shift, alt, ctrl} = decode_modifier(mod)
        [key_event(tilde_key(n), shift: shift, alt: alt, ctrl: ctrl)]

      # F1-F4 CSI letter variants (ESC [ <n> ; <mod> <letter>)
      {[1, mod], letter} when letter in [80, 81, 82, 83] ->
        {shift, alt, ctrl} = decode_modifier(mod)
        key = csi_letter_to_key(letter)
        [key_event(key, shift: shift, alt: alt, ctrl: ctrl)]

      _ ->
        []
    end
  end

  # Parse semicolon-separated numeric params ending with a final byte
  defp parse_csi_params(data) do
    parse_csi_params(data, [], [])
  end

  defp parse_csi_params(<<byte, rest::binary>>, current_digits, params)
       when byte >= ?0 and byte <= ?9 do
    parse_csi_params(rest, [byte | current_digits], params)
  end

  defp parse_csi_params(<<?;, rest::binary>>, current_digits, params) do
    num = digits_to_integer(current_digits)
    parse_csi_params(rest, [], params ++ [num])
  end

  defp parse_csi_params(<<final_byte, _rest::binary>>, current_digits, params)
       when final_byte >= 64 and final_byte <= 126 do
    num = digits_to_integer(current_digits)
    {params ++ [num], final_byte}
  end

  defp parse_csi_params(<<>>, current_digits, params) do
    num = digits_to_integer(current_digits)
    {params ++ [num], nil}
  end

  defp digits_to_integer([]), do: 0

  defp digits_to_integer(digits) do
    digits |> Enum.reverse() |> List.to_string() |> String.to_integer()
  end

  # Tilde key mapping
  defp tilde_key(1), do: :home
  defp tilde_key(2), do: :insert
  defp tilde_key(3), do: :delete
  defp tilde_key(4), do: :end
  defp tilde_key(5), do: :page_up
  defp tilde_key(6), do: :page_down
  defp tilde_key(11), do: :f1
  defp tilde_key(12), do: :f2
  defp tilde_key(13), do: :f3
  defp tilde_key(14), do: :f4
  defp tilde_key(15), do: :f5
  defp tilde_key(17), do: :f6
  defp tilde_key(18), do: :f7
  defp tilde_key(19), do: :f8
  defp tilde_key(20), do: :f9
  defp tilde_key(21), do: :f10
  defp tilde_key(23), do: :f11
  defp tilde_key(24), do: :f12
  defp tilde_key(_), do: :unknown

  # CSI letter to key mapping
  defp csi_letter_to_key(65), do: :up
  defp csi_letter_to_key(66), do: :down
  defp csi_letter_to_key(67), do: :right
  defp csi_letter_to_key(68), do: :left
  defp csi_letter_to_key(70), do: :end
  defp csi_letter_to_key(72), do: :home
  defp csi_letter_to_key(80), do: :f1
  defp csi_letter_to_key(81), do: :f2
  defp csi_letter_to_key(82), do: :f3
  defp csi_letter_to_key(83), do: :f4
  defp csi_letter_to_key(_), do: :unknown

  # Decode xterm modifier parameter (mod-1 is bitmask: bit0=shift, bit1=alt, bit2=ctrl)
  defp decode_modifier(mod) when is_integer(mod) do
    bits = mod - 1
    shift = (bits &&& 1) != 0
    alt = (bits &&& 2) != 0
    ctrl = (bits &&& 4) != 0
    {shift, alt, ctrl}
  end

  # --- SGR mouse parsing ---

  defp parse_sgr_mouse(data) do
    case Regex.run(~r/^(\d+);(\d+);(\d+)([mM])/, data) do
      [_full, button_str, x_str, y_str, kind] ->
        button_code = String.to_integer(button_str)
        x = String.to_integer(x_str)
        y = String.to_integer(y_str)

        {button, motion} = decode_sgr_button(button_code)

        action =
          case {kind, motion} do
            {_, true} -> :move
            {"M", _} -> :press
            {"m", _} -> :release
          end

        {shift, alt, ctrl} = decode_sgr_modifiers(button_code)

        [
          %Event{
            type: :mouse,
            data: %{
              button: button,
              x: x,
              y: y,
              action: action,
              shift: shift,
              alt: alt,
              ctrl: ctrl
            }
          }
        ]

      _ ->
        []
    end
  end

  defp decode_sgr_button(code) do
    motion = (code &&& 32) != 0
    base = code &&& 0x03

    button =
      cond do
        (code &&& 64) != 0 and base == 0 -> :wheel_up
        (code &&& 64) != 0 and base == 1 -> :wheel_down
        (code &&& 128) != 0 -> :extra
        base == 0 -> :left
        base == 1 -> :middle
        base == 2 -> :right
        base == 3 -> :release
        true -> :unknown
      end

    {button, motion}
  end

  defp decode_sgr_modifiers(code) do
    shift = (code &&& 4) != 0
    alt = (code &&& 8) != 0
    ctrl = (code &&& 16) != 0
    {shift, alt, ctrl}
  end

  # --- X10/normal mouse parsing ---

  defp parse_x10_mouse(button_byte, x_byte, y_byte) do
    button_code = button_byte - 32
    x = x_byte - 32
    y = y_byte - 32

    {button, motion} = decode_sgr_button(button_code)

    action =
      case motion do
        true -> :move
        false -> :press
      end

    [
      %Event{
        type: :mouse,
        data: %{
          button: button,
          x: x,
          y: y,
          action: action
        }
      }
    ]
  end

  # --- Event constructors ---

  defp key_event(key, opts \\ []) do
    data =
      %{key: key}
      |> maybe_put(:char, Keyword.get(opts, :char))
      |> maybe_put_bool(:shift, Keyword.get(opts, :shift, false))
      |> maybe_put_bool(:alt, Keyword.get(opts, :alt, false))
      |> maybe_put_bool(:ctrl, Keyword.get(opts, :ctrl, false))

    %Event{type: :key, data: data}
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp maybe_put_bool(map, _key, false), do: map
  defp maybe_put_bool(map, key, true), do: Map.put(map, key, true)
end
