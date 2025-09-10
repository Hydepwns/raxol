defmodule Raxol.Terminal.Formatting.Manager do
  @moduledoc """
  Manages terminal text formatting and styling operations.
  """

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

  @type format :: %{
          bold: boolean(),
          faint: boolean(),
          italic: boolean(),
          underline: boolean(),
          blink: boolean(),
          reverse: boolean(),
          conceal: boolean(),
          strikethrough: boolean(),
          foreground: Raxol.Terminal.Color.color() | nil,
          background: Raxol.Terminal.Color.color() | nil,
          font: non_neg_integer()
        }

  @type t :: %__MODULE__{
          current_format: format(),
          saved_format: format() | nil
        }

  @doc """
  Creates a new formatting manager instance.
  """
  def new do
    %__MODULE__{}
  end

  @doc """
  Gets the current formatting state.
  """
  def get_format(%__MODULE__{} = state) do
    state.current_format
  end

  @doc """
  Applies a new format to the current state.
  """
  def apply_format(%__MODULE__{} = state, format) when is_map(format) do
    new_format = Map.merge(state.current_format, format)
    %{state | current_format: new_format}
  end

  @doc """
  Resets the current format to default values.
  """
  def reset_format(%__MODULE__{} = state) do
    %{
      state
      | current_format: %{
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
    }
  end

  @doc """
  Saves the current format state.
  """
  def save_format(%__MODULE__{} = state) do
    %{state | saved_format: state.current_format}
  end

  @doc """
  Restores the previously saved format state.
  """
  def restore_format(%__MODULE__{} = state) do
    case state.saved_format do
      nil -> state
      format -> %{state | current_format: format}
    end
  end

  @doc """
  Sets the foreground color.
  """
  def set_foreground(%__MODULE__{} = state, color) do
    %{state | current_format: Map.put(state.current_format, :foreground, color)}
  end

  @doc """
  Sets the background color.
  """
  def set_background(%__MODULE__{} = state, color) do
    %{state | current_format: Map.put(state.current_format, :background, color)}
  end

  @doc """
  Toggles bold formatting.
  """
  def toggle_bold(%__MODULE__{} = state) do
    %{state | current_format: Map.update!(state.current_format, :bold, &(!&1))}
  end

  @doc """
  Toggles faint formatting.
  """
  def toggle_faint(%__MODULE__{} = state) do
    %{state | current_format: Map.update!(state.current_format, :faint, &(!&1))}
  end

  @doc """
  Toggles italic formatting.
  """
  def toggle_italic(%__MODULE__{} = state) do
    %{
      state
      | current_format: Map.update!(state.current_format, :italic, &(!&1))
    }
  end

  @doc """
  Toggles underline formatting.
  """
  def toggle_underline(%__MODULE__{} = state) do
    %{
      state
      | current_format: Map.update!(state.current_format, :underline, &(!&1))
    }
  end

  @doc """
  Toggles blink formatting.
  """
  def toggle_blink(%__MODULE__{} = state) do
    %{state | current_format: Map.update!(state.current_format, :blink, &(!&1))}
  end

  @doc """
  Toggles reverse video formatting.
  """
  def toggle_reverse(%__MODULE__{} = state) do
    %{
      state
      | current_format: Map.update!(state.current_format, :reverse, &(!&1))
    }
  end

  @doc """
  Toggles conceal formatting.
  """
  def toggle_conceal(%__MODULE__{} = state) do
    %{
      state
      | current_format: Map.update!(state.current_format, :conceal, &(!&1))
    }
  end

  @doc """
  Toggles strikethrough formatting.
  """
  def toggle_strikethrough(%__MODULE__{} = state) do
    %{
      state
      | current_format:
          Map.update!(state.current_format, :strikethrough, &(!&1))
    }
  end

  @doc """
  Sets the font number.
  """
  def set_font(%__MODULE__{} = state, font)
      when is_integer(font) and font >= 0 do
    %{state | current_format: Map.put(state.current_format, :font, font)}
  end

  @doc """
  Applies formatting to a string.
  """
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

  # Private helper functions for applying individual formatting attributes
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
