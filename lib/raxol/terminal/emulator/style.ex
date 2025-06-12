defmodule Raxol.Terminal.Emulator.Style do
  @moduledoc """
  Handles text styling and formatting for the terminal emulator.
  Provides functions for managing character attributes, colors, and text formatting.
  """

  require Raxol.Core.Runtime.Log

  alias Raxol.Terminal.ANSI.TextFormatting
  alias Raxol.Terminal.Emulator.Struct, as: EmulatorStruct

  @behaviour Raxol.Terminal.Emulator.Style

  @impl true
  @doc """
  Sets the text style attributes.
  Returns {:ok, updated_emulator} or {:error, reason}.
  """
  @spec set_attributes(EmulatorStruct.t(), list()) ::
          {:ok, EmulatorStruct.t()} | {:error, String.t()}
  def set_attributes(%EmulatorStruct{} = emulator, attributes)
      when is_list(attributes) do
    updated_style =
      Enum.reduce(attributes, emulator.style, fn attr, style ->
        TextFormatting.apply_attribute(style, attr)
      end)

    {:ok, %{emulator | style: updated_style}}
  end

  def set_attributes(%EmulatorStruct{} = _emulator, invalid_attributes) do
    {:error, "Invalid attributes: #{inspect(invalid_attributes)}"}
  end

  @impl true
  @doc """
  Sets the foreground color.
  Returns {:ok, updated_emulator} or {:error, reason}.
  """
  @spec set_foreground(EmulatorStruct.t(), atom() | tuple()) ::
          {:ok, EmulatorStruct.t()} | {:error, String.t()}
  def set_foreground(%EmulatorStruct{} = emulator, color) do
    updated_style = TextFormatting.set_foreground(emulator.style, color)
    {:ok, %{emulator | style: updated_style}}
  end

  @impl true
  @doc """
  Sets the background color.
  Returns {:ok, updated_emulator} or {:error, reason}.
  """
  @spec set_background(EmulatorStruct.t(), atom() | tuple()) ::
          {:ok, EmulatorStruct.t()} | {:error, String.t()}
  def set_background(%EmulatorStruct{} = emulator, color) do
    updated_style = TextFormatting.set_background(emulator.style, color)
    {:ok, %{emulator | style: updated_style}}
  end

  @impl true
  @doc """
  Resets all text attributes to default.
  Returns {:ok, updated_emulator}.
  """
  @spec reset_attributes(EmulatorStruct.t()) :: {:ok, EmulatorStruct.t()}
  def reset_attributes(%EmulatorStruct{} = emulator) do
    updated_style = TextFormatting.reset(emulator.style)
    {:ok, %{emulator | style: updated_style}}
  end

  @impl true
  @doc """
  Sets the text intensity (bold, faint).
  Returns {:ok, updated_emulator} or {:error, reason}.
  """
  @spec set_intensity(EmulatorStruct.t(), :normal | :bold | :faint) ::
          {:ok, EmulatorStruct.t()} | {:error, String.t()}
  def set_intensity(%EmulatorStruct{} = emulator, :bold) do
    updated_style = TextFormatting.apply_attribute(emulator.style, :bold)
    {:ok, %{emulator | style: updated_style}}
  end

  def set_intensity(%EmulatorStruct{} = emulator, :faint) do
    updated_style = TextFormatting.apply_attribute(emulator.style, :faint)
    {:ok, %{emulator | style: updated_style}}
  end

  def set_intensity(%EmulatorStruct{} = emulator, :normal) do
    updated_style =
      TextFormatting.apply_attribute(emulator.style, :normal_intensity)

    {:ok, %{emulator | style: updated_style}}
  end

  def set_intensity(%EmulatorStruct{} = _emulator, invalid_intensity) do
    {:error, "Invalid intensity: #{inspect(invalid_intensity)}"}
  end

  @impl true
  @doc """
  Sets the text decoration (underline, strikethrough, etc.).
  Returns {:ok, updated_emulator} or {:error, reason}.
  """
  @spec set_decoration(EmulatorStruct.t(), atom()) ::
          {:ok, EmulatorStruct.t()} | {:error, String.t()}
  def set_decoration(%EmulatorStruct{} = emulator, decoration) do
    updated_style = TextFormatting.apply_attribute(emulator.style, decoration)
    {:ok, %{emulator | style: updated_style}}
  end

  @impl true
  @doc """
  Sets the text blink mode.
  Returns {:ok, updated_emulator} or {:error, reason}.
  """
  @spec set_blink(EmulatorStruct.t(), :none | :slow | :rapid) ::
          {:ok, EmulatorStruct.t()} | {:error, String.t()}
  def set_blink(%EmulatorStruct{} = emulator, :none) do
    updated_style = TextFormatting.apply_attribute(emulator.style, :no_blink)
    {:ok, %{emulator | style: updated_style}}
  end

  def set_blink(%EmulatorStruct{} = emulator, _blink) do
    updated_style = TextFormatting.apply_attribute(emulator.style, :blink)
    {:ok, %{emulator | style: updated_style}}
  end

  @doc """
  Sets the text visibility.
  Returns {:ok, updated_emulator} or {:error, reason}.
  """
  @spec set_visibility(EmulatorStruct.t(), :visible | :hidden) ::
          {:ok, EmulatorStruct.t()} | {:error, String.t()}
  def set_visibility(%EmulatorStruct{} = emulator, :visible) do
    updated_style = TextFormatting.apply_attribute(emulator.style, :reveal)
    {:ok, %{emulator | style: updated_style}}
  end

  def set_visibility(%EmulatorStruct{} = emulator, :hidden) do
    updated_style = TextFormatting.apply_attribute(emulator.style, :conceal)
    {:ok, %{emulator | style: updated_style}}
  end

  @doc """
  Sets the text inverse mode.
  Returns {:ok, updated_emulator} or {:error, reason}.
  """
  @spec set_inverse(EmulatorStruct.t(), boolean()) ::
          {:ok, EmulatorStruct.t()} | {:error, String.t()}
  def set_inverse(%EmulatorStruct{} = emulator, true) do
    updated_style = TextFormatting.apply_attribute(emulator.style, :reverse)
    {:ok, %{emulator | style: updated_style}}
  end

  def set_inverse(%EmulatorStruct{} = emulator, false) do
    updated_style = TextFormatting.apply_attribute(emulator.style, :no_reverse)
    {:ok, %{emulator | style: updated_style}}
  end

  def set_inverse(%EmulatorStruct{} = _emulator, invalid_inverse) do
    {:error, "Invalid inverse mode: #{inspect(invalid_inverse)}"}
  end

  @doc """
  Gets the current text style.
  Returns the current style.
  """
  @spec get_style(EmulatorStruct.t()) :: TextFormatting.text_style()
  def get_style(%EmulatorStruct{} = emulator) do
    emulator.style
  end
end
