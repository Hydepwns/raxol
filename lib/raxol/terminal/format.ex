defmodule Raxol.Terminal.Format do
  @moduledoc """
  Unified terminal text formatting and styling operations.

  This module manages formatting state (bold, italic, colors, etc.) and provides
  functions for applying ANSI escape codes to text. It consolidates the
  previously separate FormattingManager and Formatting.Manager modules.

  ## Usage

      iex> format = Format.new()
      iex> format = Format.set_foreground(format, 196)
      iex> format = Format.toggle_bold(format)
      iex> Format.apply_formatting(format, "Hello")
      "\e[1m\e[38;5;196mHello\e[39m\e[22m"

  """

  @typedoc "Terminal text attributes"
  @type format :: %{
          bold: boolean(),
          faint: boolean(),
          italic: boolean(),
          underline: boolean(),
          blink: boolean(),
          reverse: boolean(),
          conceal: boolean(),
          strikethrough: boolean(),
          foreground: term() | nil,
          background: term() | nil,
          font: non_neg_integer()
        }

  @typedoc "Format state with current and saved formats"
  @type t :: %__MODULE__{
          current_format: format(),
          saved_format: format() | nil
        }

  defstruct current_format: %{
              bold: false,
              faint: false,
              italic: false,
              underline: false,
              blink: false,
              reverse: false,
              conceal: false,
              strikethrough: false,
              foreground: nil,
              background: nil,
              font: 0
            },
            saved_format: nil

  @default_format %{
    bold: false,
    faint: false,
    italic: false,
    underline: false,
    blink: false,
    reverse: false,
    conceal: false,
    strikethrough: false,
    foreground: nil,
    background: nil,
    font: 0
  }

  # --- Constructor ---

  @doc """
  Creates a new formatting state with default values.
  """
  @spec new() :: t()
  def new do
    %__MODULE__{}
  end

  # --- Format Access ---

  @doc """
  Gets the current formatting state.
  """
  @spec get_format(t()) :: format()
  def get_format(%__MODULE__{} = state) do
    state.current_format
  end

  @doc """
  Applies a map of format updates to the current state.
  """
  @spec apply_format(t(), map()) :: t()
  def apply_format(%__MODULE__{} = state, format) when is_map(format) do
    new_format = Map.merge(state.current_format, format)
    %{state | current_format: new_format}
  end

  @doc """
  Resets the current format to default values.
  """
  @spec reset_format(t()) :: t()
  def reset_format(%__MODULE__{} = state) do
    %{state | current_format: @default_format}
  end

  # --- Save/Restore ---

  @doc """
  Saves the current format state for later restoration.
  """
  @spec save_format(t()) :: t()
  def save_format(%__MODULE__{} = state) do
    %{state | saved_format: state.current_format}
  end

  @doc """
  Restores the previously saved format state.

  Returns unchanged state if no format was saved.
  """
  @spec restore_format(t()) :: t()
  def restore_format(%__MODULE__{saved_format: nil} = state), do: state

  def restore_format(%__MODULE__{saved_format: format} = state) do
    %{state | current_format: format}
  end

  # --- Color Operations ---

  @doc """
  Sets the foreground color.

  Color can be an 8-bit color code (0-255) or nil for default.
  """
  @spec set_foreground(t(), term() | nil) :: t()
  def set_foreground(%__MODULE__{} = state, color) do
    update_format(state, :foreground, color)
  end

  @doc """
  Sets the background color.

  Color can be an 8-bit color code (0-255) or nil for default.
  """
  @spec set_background(t(), term() | nil) :: t()
  def set_background(%__MODULE__{} = state, color) do
    update_format(state, :background, color)
  end

  @doc """
  Gets the current foreground color.
  """
  @spec get_foreground(t()) :: term() | nil
  def get_foreground(%__MODULE__{} = state) do
    state.current_format.foreground
  end

  @doc """
  Gets the current background color.
  """
  @spec get_background(t()) :: term() | nil
  def get_background(%__MODULE__{} = state) do
    state.current_format.background
  end

  # --- Attribute Operations ---

  @doc """
  Sets the specified attribute to true.
  """
  @spec set_attribute(t(), atom()) :: t()
  def set_attribute(%__MODULE__{} = state, attribute) when is_atom(attribute) do
    update_format(state, attribute, true)
  end

  @doc """
  Resets the specified attribute to false.
  """
  @spec reset_attribute(t(), atom()) :: t()
  def reset_attribute(%__MODULE__{} = state, attribute)
      when is_atom(attribute) do
    update_format(state, attribute, false)
  end

  @doc """
  Checks if the specified attribute is set.
  """
  @spec attribute_set?(t(), atom()) :: boolean()
  def attribute_set?(%__MODULE__{} = state, attribute) do
    Map.get(state.current_format, attribute, false) == true
  end

  @doc """
  Returns a list of all attributes that are currently set to true.
  """
  @spec get_set_attributes(t()) :: [{atom(), true}]
  def get_set_attributes(%__MODULE__{} = state) do
    state.current_format
    |> Enum.filter(fn {_key, value} -> value == true end)
  end

  # --- Toggle Operations ---

  @doc "Toggles bold formatting."
  @spec toggle_bold(t()) :: t()
  def toggle_bold(%__MODULE__{} = state), do: toggle_attribute(state, :bold)

  @doc "Toggles faint formatting."
  @spec toggle_faint(t()) :: t()
  def toggle_faint(%__MODULE__{} = state), do: toggle_attribute(state, :faint)

  @doc "Toggles italic formatting."
  @spec toggle_italic(t()) :: t()
  def toggle_italic(%__MODULE__{} = state), do: toggle_attribute(state, :italic)

  @doc "Toggles underline formatting."
  @spec toggle_underline(t()) :: t()
  def toggle_underline(%__MODULE__{} = state),
    do: toggle_attribute(state, :underline)

  @doc "Toggles blink formatting."
  @spec toggle_blink(t()) :: t()
  def toggle_blink(%__MODULE__{} = state), do: toggle_attribute(state, :blink)

  @doc "Toggles reverse video formatting."
  @spec toggle_reverse(t()) :: t()
  def toggle_reverse(%__MODULE__{} = state),
    do: toggle_attribute(state, :reverse)

  @doc "Toggles conceal formatting."
  @spec toggle_conceal(t()) :: t()
  def toggle_conceal(%__MODULE__{} = state),
    do: toggle_attribute(state, :conceal)

  @doc "Toggles strikethrough formatting."
  @spec toggle_strikethrough(t()) :: t()
  def toggle_strikethrough(%__MODULE__{} = state),
    do: toggle_attribute(state, :strikethrough)

  # --- Font ---

  @doc """
  Sets the font number (0-9 for standard ANSI fonts).
  """
  @spec set_font(t(), non_neg_integer()) :: t()
  def set_font(%__MODULE__{} = state, font)
      when is_integer(font) and font >= 0 do
    update_format(state, :font, font)
  end

  # --- ANSI Application ---

  @doc """
  Applies the current formatting to a string, wrapping it with ANSI escape codes.

  Each attribute that is enabled will add the appropriate SGR codes around the text.
  """
  @spec apply_formatting(t(), String.t()) :: String.t()
  def apply_formatting(%__MODULE__{} = state, text) when is_binary(text) do
    format = state.current_format

    text
    |> maybe_apply_bold(format.bold)
    |> maybe_apply_faint(format.faint)
    |> maybe_apply_italic(format.italic)
    |> maybe_apply_underline(format.underline)
    |> maybe_apply_blink(format.blink)
    |> maybe_apply_reverse(format.reverse)
    |> maybe_apply_conceal(format.conceal)
    |> maybe_apply_strikethrough(format.strikethrough)
    |> maybe_apply_foreground(format.foreground)
    |> maybe_apply_background(format.background)
  end

  @doc """
  Generates the ANSI escape sequence for the current format without text.

  Returns a tuple of {start_sequence, end_sequence} that can be used to wrap text.
  """
  @spec to_ansi_sequences(t()) :: {String.t(), String.t()}
  def to_ansi_sequences(%__MODULE__{} = state) do
    format = state.current_format
    start_codes = []
    end_codes = []

    {start_codes, end_codes} =
      if format.bold,
        do: {[1 | start_codes], [22 | end_codes]},
        else: {start_codes, end_codes}

    {start_codes, end_codes} =
      if format.faint,
        do: {[2 | start_codes], [22 | end_codes]},
        else: {start_codes, end_codes}

    {start_codes, end_codes} =
      if format.italic,
        do: {[3 | start_codes], [23 | end_codes]},
        else: {start_codes, end_codes}

    {start_codes, end_codes} =
      if format.underline,
        do: {[4 | start_codes], [24 | end_codes]},
        else: {start_codes, end_codes}

    {start_codes, end_codes} =
      if format.blink,
        do: {[5 | start_codes], [25 | end_codes]},
        else: {start_codes, end_codes}

    {start_codes, end_codes} =
      if format.reverse,
        do: {[7 | start_codes], [27 | end_codes]},
        else: {start_codes, end_codes}

    {start_codes, end_codes} =
      if format.conceal,
        do: {[8 | start_codes], [28 | end_codes]},
        else: {start_codes, end_codes}

    {start_codes, end_codes} =
      if format.strikethrough,
        do: {[9 | start_codes], [29 | end_codes]},
        else: {start_codes, end_codes}

    {start_codes, end_codes} =
      case format.foreground do
        nil -> {start_codes, end_codes}
        color -> {[{38, 5, color} | start_codes], [39 | end_codes]}
      end

    {start_codes, end_codes} =
      case format.background do
        nil -> {start_codes, end_codes}
        color -> {[{48, 5, color} | start_codes], [49 | end_codes]}
      end

    start_seq = build_sgr_sequence(start_codes)
    end_seq = build_sgr_sequence(end_codes)

    {start_seq, end_seq}
  end

  # --- Private Helpers ---

  defp update_format(%__MODULE__{} = state, key, value) do
    %{state | current_format: Map.put(state.current_format, key, value)}
  end

  defp toggle_attribute(%__MODULE__{} = state, attribute) do
    %{
      state
      | current_format: Map.update!(state.current_format, attribute, &(!&1))
    }
  end

  defp build_sgr_sequence([]), do: ""

  defp build_sgr_sequence(codes) do
    params =
      codes
      |> Enum.reverse()
      |> Enum.map(fn
        {a, b, c} -> "#{a};#{b};#{c}"
        code -> to_string(code)
      end)
      |> Enum.join(";")

    "\e[#{params}m"
  end

  # ANSI application helpers
  defp maybe_apply_bold(text, true), do: "\e[1m#{text}\e[22m"
  defp maybe_apply_bold(text, false), do: text

  defp maybe_apply_faint(text, true), do: "\e[2m#{text}\e[22m"
  defp maybe_apply_faint(text, false), do: text

  defp maybe_apply_italic(text, true), do: "\e[3m#{text}\e[23m"
  defp maybe_apply_italic(text, false), do: text

  defp maybe_apply_underline(text, true), do: "\e[4m#{text}\e[24m"
  defp maybe_apply_underline(text, false), do: text

  defp maybe_apply_blink(text, true), do: "\e[5m#{text}\e[25m"
  defp maybe_apply_blink(text, false), do: text

  defp maybe_apply_reverse(text, true), do: "\e[7m#{text}\e[27m"
  defp maybe_apply_reverse(text, false), do: text

  defp maybe_apply_conceal(text, true), do: "\e[8m#{text}\e[28m"
  defp maybe_apply_conceal(text, false), do: text

  defp maybe_apply_strikethrough(text, true), do: "\e[9m#{text}\e[29m"
  defp maybe_apply_strikethrough(text, false), do: text

  defp maybe_apply_foreground(text, nil), do: text
  defp maybe_apply_foreground(text, color), do: "\e[38;5;#{color}m#{text}\e[39m"

  defp maybe_apply_background(text, nil), do: text
  defp maybe_apply_background(text, color), do: "\e[48;5;#{color}m#{text}\e[49m"
end
