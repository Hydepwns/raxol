defmodule Raxol.Terminal.Cursor.Style do
  @moduledoc """
  Handles cursor style and visibility control for the terminal emulator.

  This module provides functions for changing cursor appearance, controlling
  visibility, and managing cursor blinking.
  """

  @behaviour Raxol.Terminal.Cursor.Style

  alias Raxol.Terminal.Cursor.Manager

  @impl true
  @doc """
  Sets the cursor style to block.

  ## Examples

      iex> alias Raxol.Terminal.Cursor.{Manager, Style}
      iex> cursor = Manager.new()
      iex> cursor = Style.set_block(cursor)
      iex> cursor.style
      :block
  """
  def set_block(%Manager{} = cursor) do
    Manager.set_style(cursor, :block)
  end

  @impl true
  @doc """
  Sets the cursor style to underline.

  ## Examples

      iex> alias Raxol.Terminal.Cursor.{Manager, Style}
      iex> cursor = Manager.new()
      iex> cursor = Style.set_underline(cursor)
      iex> cursor.style
      :underline
  """
  def set_underline(%Manager{} = cursor) do
    Manager.set_style(cursor, :underline)
  end

  @impl true
  @doc """
  Sets the cursor style to bar.

  ## Examples

      iex> alias Raxol.Terminal.Cursor.{Manager, Style}
      iex> cursor = Manager.new()
      iex> cursor = Style.set_bar(cursor)
      iex> cursor.style
      :bar
  """
  def set_bar(%Manager{} = cursor) do
    Manager.set_style(cursor, :bar)
  end

  @impl true
  @doc """
  Sets a custom cursor shape.

  ## Examples

      iex> alias Raxol.Terminal.Cursor.{Manager, Style}
      iex> cursor = Manager.new()
      iex> cursor = Style.set_custom(cursor, "█", {2, 1})
      iex> cursor.style
      :custom
      iex> cursor.custom_shape
      "█"
  """
  def set_custom(%Manager{} = cursor, shape, dimensions) do
    Manager.set_custom_shape(cursor, shape, dimensions)
  end

  @impl true
  @doc """
  Makes the cursor visible.

  ## Examples

      iex> alias Raxol.Terminal.Cursor.{Manager, Style}
      iex> cursor = Manager.new()
      iex> cursor = Manager.set_state(cursor, :hidden)
      iex> cursor = Style.show(cursor)
      iex> cursor.state
      :visible
  """
  def show(%Manager{} = cursor) do
    Manager.set_state(cursor, :visible)
  end

  @impl true
  @doc """
  Hides the cursor.

  ## Examples

      iex> alias Raxol.Terminal.Cursor.{Manager, Style}
      iex> cursor = Manager.new()
      iex> cursor = Style.hide(cursor)
      iex> cursor.state
      :hidden
  """
  def hide(%Manager{} = cursor) do
    Manager.set_state(cursor, :hidden)
  end

  @impl true
  @doc """
  Makes the cursor blink.

  ## Examples

      iex> alias Raxol.Terminal.Cursor.{Manager, Style}
      iex> cursor = Manager.new()
      iex> cursor = Style.blink(cursor)
      iex> cursor.state
      :blinking
  """
  def blink(%Manager{} = cursor) do
    Manager.set_state(cursor, :blinking)
  end

  @impl true
  @doc """
  Sets the cursor blink rate in milliseconds.

  ## Examples

      iex> alias Raxol.Terminal.Cursor.{Manager, Style}
      iex> cursor = Manager.new()
      iex> cursor = Style.set_blink_rate(cursor, 1000)
      iex> cursor.blink_rate
      1000
  """
  def set_blink_rate(%Manager{} = cursor, rate)
      when is_integer(rate) and rate > 0 do
    %{cursor | blink_rate: rate}
  end

  @impl true
  @doc """
  Updates the cursor blink state and returns the updated cursor and visibility.

  ## Examples

      iex> alias Raxol.Terminal.Cursor.{Manager, Style}
      iex> cursor = Manager.new()
      iex> cursor = Style.blink(cursor)
      iex> {cursor, visible} = Style.update_blink(cursor)
      iex> is_boolean(visible)
      true
  """
  def update_blink(%Manager{} = cursor) do
    Manager.update_blink(cursor)
  end

  @impl true
  @doc """
  Toggles the cursor visibility.

  ## Examples

      iex> alias Raxol.Terminal.Cursor.{Manager, Style}
      iex> cursor = Manager.new()
      iex> cursor = Style.toggle_visibility(cursor)
      iex> cursor.state
      :hidden
      iex> cursor = Style.toggle_visibility(cursor)
      iex> cursor.state
      :visible
  """
  def toggle_visibility(%Manager{} = cursor) do
    case cursor.state do
      :visible -> hide(cursor)
      :hidden -> show(cursor)
      :blinking -> hide(cursor)
    end
  end

  @impl true
  @doc """
  Toggles the cursor blinking state.

  ## Examples

      iex> alias Raxol.Terminal.Cursor.{Manager, Style}
      iex> cursor = Manager.new()
      iex> cursor = Style.toggle_blink(cursor)
      iex> cursor.state
      :blinking
      iex> cursor = Style.toggle_blink(cursor)
      iex> cursor.state
      :visible
  """
  def toggle_blink(%Manager{} = cursor) do
    case cursor.state do
      :blinking -> show(cursor)
      _ -> blink(cursor)
    end
  end

  @impl true
  @doc """
  Gets the current cursor style.

  ## Examples

      iex> alias Raxol.Terminal.Cursor.{Manager, Style}
      iex> cursor = Manager.new()
      iex> Style.get_style(cursor)
      :block
  """
  def get_style(%Manager{} = cursor) do
    cursor.style
  end

  @impl true
  @doc """
  Gets the current cursor state.

  ## Examples

      iex> alias Raxol.Terminal.Cursor.{Manager, Style}
      iex> cursor = Manager.new()
      iex> Style.get_state(cursor)
      :visible
  """
  def get_state(%Manager{} = cursor) do
    cursor.state
  end

  @impl true
  @doc """
  Gets the current cursor blink mode.

  ## Examples

      iex> alias Raxol.Terminal.Cursor.{Manager, Style}
      iex> cursor = Manager.new()
      iex> Style.get_blink(cursor)
      :none
  """
  def get_blink(%Manager{} = cursor) do
    cursor.blink
  end
end
