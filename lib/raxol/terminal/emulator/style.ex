defmodule Raxol.Terminal.Emulator.Style do
  @moduledoc """
  Handles text styling and formatting for the terminal emulator.
  Provides functions for managing character attributes, colors, and text formatting.
  """

  require Raxol.Core.Runtime.Log

  alias Raxol.Terminal.ANSI.TextFormatting
  alias Raxol.Terminal.Emulator

  @behaviour Raxol.Terminal.Emulator.Style

  @impl true
  @doc """
  Sets the text style attributes.
  Returns {:ok, updated_emulator} or {:error, reason}.
  """
  @spec set_attributes(Emulator.t(), list()) ::
          {:ok, Emulator.t()} | {:error, String.t()}
  def set_attributes(%Emulator{} = emulator, attributes)
      when is_list(attributes) do
    updated_style =
      Enum.reduce(attributes, emulator.style, fn attr, style ->
        TextFormatting.apply_attribute(style, attr)
      end)

    {:ok, %{emulator | style: updated_style}}
  end

  def set_attributes(%Emulator{} = _emulator, invalid_attributes) do
    {:error, "Invalid attributes: #{inspect(invalid_attributes)}"}
  end

  @impl true
  @doc """
  Sets the foreground color.
  Returns {:ok, updated_emulator} or {:error, reason}.
  """
  @spec set_foreground(Emulator.t(), atom() | tuple()) ::
          {:ok, Emulator.t()} | {:error, String.t()}
  def set_foreground(%Emulator{} = emulator, color) do
    updated_style = TextFormatting.set_foreground(emulator.style, color)
    {:ok, %{emulator | style: updated_style}}
  end

  @impl true
  @doc """
  Sets the background color.
  Returns {:ok, updated_emulator} or {:error, reason}.
  """
  @spec set_background(Emulator.t(), atom() | tuple()) ::
          {:ok, Emulator.t()} | {:error, String.t()}
  def set_background(%Emulator{} = emulator, color) do
    updated_style = TextFormatting.set_background(emulator.style, color)
    {:ok, %{emulator | style: updated_style}}
  end

  @impl true
  @doc """
  Resets all text attributes to default.
  Returns {:ok, updated_emulator}.
  """
  @spec reset_attributes(Emulator.t()) :: {:ok, Emulator.t()}
  def reset_attributes(%Emulator{} = emulator) do
    updated_style = TextFormatting.reset(emulator.style)
    {:ok, %{emulator | style: updated_style}}
  end

  @impl true
  @doc """
  Sets the text intensity (bold, faint).
  Returns {:ok, updated_emulator} or {:error, reason}.
  """
  @spec set_intensity(Emulator.t(), :normal | :bold | :faint) ::
          {:ok, Emulator.t()} | {:error, String.t()}
  def set_intensity(%Emulator{} = emulator, :bold) do
    updated_style = TextFormatting.apply_attribute(emulator.style, :bold)
    {:ok, %{emulator | style: updated_style}}
  end

  def set_intensity(%Emulator{} = emulator, :faint) do
    updated_style = TextFormatting.apply_attribute(emulator.style, :faint)
    {:ok, %{emulator | style: updated_style}}
  end

  def set_intensity(%Emulator{} = emulator, :normal) do
    updated_style =
      TextFormatting.apply_attribute(emulator.style, :normal_intensity)

    {:ok, %{emulator | style: updated_style}}
  end

  def set_intensity(%Emulator{} = _emulator, invalid_intensity) do
    {:error, "Invalid intensity: #{inspect(invalid_intensity)}"}
  end

  @impl true
  @doc """
  Sets the text decoration (underline, strikethrough, etc.).
  Returns {:ok, updated_emulator} or {:error, reason}.
  """
  @spec set_decoration(Emulator.t(), atom()) ::
          {:ok, Emulator.t()} | {:error, String.t()}
  def set_decoration(%Emulator{} = emulator, decoration) do
    updated_style = TextFormatting.apply_attribute(emulator.style, decoration)
    {:ok, %{emulator | style: updated_style}}
  end

  @impl true
  @doc """
  Sets the text blink mode.
  Returns {:ok, updated_emulator} or {:error, reason}.
  """
  @spec set_blink(Emulator.t(), :none | :slow | :rapid) ::
          {:ok, Emulator.t()} | {:error, String.t()}
  def set_blink(%Emulator{} = emulator, :none) do
    updated_style = TextFormatting.apply_attribute(emulator.style, :no_blink)
    {:ok, %{emulator | style: updated_style}}
  end

  def set_blink(%Emulator{} = emulator, _blink) do
    updated_style = TextFormatting.apply_attribute(emulator.style, :blink)
    {:ok, %{emulator | style: updated_style}}
  end

  @doc """
  Sets the text visibility.
  Returns {:ok, updated_emulator} or {:error, reason}.
  """
  @spec set_visibility(Emulator.t(), :visible | :hidden) ::
          {:ok, Emulator.t()} | {:error, String.t()}
  def set_visibility(%Emulator{} = emulator, :visible) do
    updated_style = TextFormatting.apply_attribute(emulator.style, :reveal)
    {:ok, %{emulator | style: updated_style}}
  end

  def set_visibility(%Emulator{} = emulator, :hidden) do
    updated_style = TextFormatting.apply_attribute(emulator.style, :conceal)
    {:ok, %{emulator | style: updated_style}}
  end

  @doc """
  Sets the text inverse mode.
  Returns {:ok, updated_emulator} or {:error, reason}.
  """
  @spec set_inverse(Emulator.t(), boolean()) ::
          {:ok, Emulator.t()} | {:error, String.t()}
  def set_inverse(%Emulator{} = emulator, true) do
    updated_style = TextFormatting.apply_attribute(emulator.style, :reverse)
    {:ok, %{emulator | style: updated_style}}
  end

  def set_inverse(%Emulator{} = emulator, false) do
    updated_style = TextFormatting.apply_attribute(emulator.style, :no_reverse)
    {:ok, %{emulator | style: updated_style}}
  end

  def set_inverse(%Emulator{} = _emulator, invalid_inverse) do
    {:error, "Invalid inverse mode: #{inspect(invalid_inverse)}"}
  end

  @doc """
  Gets the current text style.
  Returns the current style.
  """
  @spec get_style(Emulator.t()) :: TextFormatting.text_style()
  def get_style(%Emulator{} = emulator) do
    emulator.style
  end
end
