defmodule Raxol.Terminal.Emulator.Style do
  @moduledoc """
  Handles text styling and formatting for the terminal emulator.
  Provides functions for managing character attributes, colors, and text formatting.
  """

  require Logger

  alias Raxol.Terminal.{
    ANSI.TextFormatting,
    Core
  }

  @doc """
  Sets the text style attributes.
  Returns {:ok, updated_emulator} or {:error, reason}.
  """
  @spec set_attributes(Core.t(), list()) :: {:ok, Core.t()} | {:error, String.t()}
  def set_attributes(%Core{} = emulator, attributes) when is_list(attributes) do
    case TextFormatting.set_attributes(emulator.style, attributes) do
      {:ok, updated_style} ->
        {:ok, %{emulator | style: updated_style}}
      {:error, reason} ->
        {:error, reason}
    end
  end

  def set_attributes(%Core{} = _emulator, invalid_attributes) do
    {:error, "Invalid attributes: #{inspect(invalid_attributes)}"}
  end

  @doc """
  Sets the foreground color.
  Returns {:ok, updated_emulator} or {:error, reason}.
  """
  @spec set_foreground(Core.t(), TextFormatting.color()) :: {:ok, Core.t()} | {:error, String.t()}
  def set_foreground(%Core{} = emulator, color) do
    case TextFormatting.set_foreground(emulator.style, color) do
      {:ok, updated_style} ->
        {:ok, %{emulator | style: updated_style}}
      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Sets the background color.
  Returns {:ok, updated_emulator} or {:error, reason}.
  """
  @spec set_background(Core.t(), TextFormatting.color()) :: {:ok, Core.t()} | {:error, String.t()}
  def set_background(%Core{} = emulator, color) do
    case TextFormatting.set_background(emulator.style, color) do
      {:ok, updated_style} ->
        {:ok, %{emulator | style: updated_style}}
      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Resets all text attributes to default.
  Returns {:ok, updated_emulator}.
  """
  @spec reset_attributes(Core.t()) :: {:ok, Core.t()}
  def reset_attributes(%Core{} = emulator) do
    updated_style = TextFormatting.reset(emulator.style)
    {:ok, %{emulator | style: updated_style}}
  end

  @doc """
  Sets the text intensity (bold, faint).
  Returns {:ok, updated_emulator} or {:error, reason}.
  """
  @spec set_intensity(Core.t(), :normal | :bold | :faint) :: {:ok, Core.t()} | {:error, String.t()}
  def set_intensity(%Core{} = emulator, intensity) when intensity in [:normal, :bold, :faint] do
    case TextFormatting.set_intensity(emulator.style, intensity) do
      {:ok, updated_style} ->
        {:ok, %{emulator | style: updated_style}}
      {:error, reason} ->
        {:error, reason}
    end
  end

  def set_intensity(%Core{} = _emulator, invalid_intensity) do
    {:error, "Invalid intensity: #{inspect(invalid_intensity)}"}
  end

  @doc """
  Sets the text decoration (underline, strikethrough, etc.).
  Returns {:ok, updated_emulator} or {:error, reason}.
  """
  @spec set_decoration(Core.t(), TextFormatting.decoration()) :: {:ok, Core.t()} | {:error, String.t()}
  def set_decoration(%Core{} = emulator, decoration) do
    case TextFormatting.set_decoration(emulator.style, decoration) do
      {:ok, updated_style} ->
        {:ok, %{emulator | style: updated_style}}
      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Sets the text blink mode.
  Returns {:ok, updated_emulator} or {:error, reason}.
  """
  @spec set_blink(Core.t(), :none | :slow | :rapid) :: {:ok, Core.t()} | {:error, String.t()}
  def set_blink(%Core{} = emulator, blink) when blink in [:none, :slow, :rapid] do
    case TextFormatting.set_blink(emulator.style, blink) do
      {:ok, updated_style} ->
        {:ok, %{emulator | style: updated_style}}
      {:error, reason} ->
        {:error, reason}
    end
  end

  def set_blink(%Core{} = _emulator, invalid_blink) do
    {:error, "Invalid blink mode: #{inspect(invalid_blink)}"}
  end

  @doc """
  Sets the text visibility.
  Returns {:ok, updated_emulator} or {:error, reason}.
  """
  @spec set_visibility(Core.t(), :visible | :hidden) :: {:ok, Core.t()} | {:error, String.t()}
  def set_visibility(%Core{} = emulator, visibility) when visibility in [:visible, :hidden] do
    case TextFormatting.set_visibility(emulator.style, visibility) do
      {:ok, updated_style} ->
        {:ok, %{emulator | style: updated_style}}
      {:error, reason} ->
        {:error, reason}
    end
  end

  def set_visibility(%Core{} = _emulator, invalid_visibility) do
    {:error, "Invalid visibility: #{inspect(invalid_visibility)}"}
  end

  @doc """
  Sets the text inverse mode.
  Returns {:ok, updated_emulator} or {:error, reason}.
  """
  @spec set_inverse(Core.t(), boolean()) :: {:ok, Core.t()} | {:error, String.t()}
  def set_inverse(%Core{} = emulator, inverse) when is_boolean(inverse) do
    case TextFormatting.set_inverse(emulator.style, inverse) do
      {:ok, updated_style} ->
        {:ok, %{emulator | style: updated_style}}
      {:error, reason} ->
        {:error, reason}
    end
  end

  def set_inverse(%Core{} = _emulator, invalid_inverse) do
    {:error, "Invalid inverse mode: #{inspect(invalid_inverse)}"}
  end

  @doc """
  Gets the current text style.
  Returns the current style.
  """
  @spec get_style(Core.t()) :: TextFormatting.text_style()
  def get_style(%Core{} = emulator) do
    emulator.style
  end
end
