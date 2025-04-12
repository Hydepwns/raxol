defmodule Raxol.Terminal.Cursor.Style do
  @moduledoc """
  Handles cursor style and visibility control for the terminal emulator.

  This module provides functions for changing cursor appearance, controlling
  visibility, and managing cursor blinking.
  """

  alias Raxol.Terminal.Cursor.Manager

  @doc """
  Sets the cursor style to block.

  ## Examples

      iex> cursor = Cursor.Manager.new()
      iex> cursor = Cursor.Style.set_block(cursor)
      iex> cursor.style
      :block
  """
  def set_block(%Manager{} = cursor) do
    Manager.set_style(cursor, :block)
  end

  @doc """
  Sets the cursor style to underline.

  ## Examples

      iex> cursor = Cursor.Manager.new()
      iex> cursor = Cursor.Style.set_underline(cursor)
      iex> cursor.style
      :underline
  """
  def set_underline(%Manager{} = cursor) do
    Manager.set_style(cursor, :underline)
  end

  @doc """
  Sets the cursor style to bar.

  ## Examples

      iex> cursor = Cursor.Manager.new()
      iex> cursor = Cursor.Style.set_bar(cursor)
      iex> cursor.style
      :bar
  """
  def set_bar(%Manager{} = cursor) do
    Manager.set_style(cursor, :bar)
  end

  @doc """
  Sets a custom cursor shape.

  ## Examples

      iex> cursor = Cursor.Manager.new()
      iex> cursor = Cursor.Style.set_custom(cursor, "█", {2, 1})
      iex> cursor.style
      :custom
      iex> cursor.custom_shape
      "█"
  """
  def set_custom(%Manager{} = cursor, shape, dimensions) do
    Manager.set_custom_shape(cursor, shape, dimensions)
  end

  @doc """
  Makes the cursor visible.

  ## Examples

      iex> cursor = Cursor.Manager.new()
      iex> cursor = Cursor.Manager.set_state(cursor, :hidden)
      iex> cursor = Cursor.Style.show(cursor)
      iex> cursor.state
      :visible
  """
  def show(%Manager{} = cursor) do
    Manager.set_state(cursor, :visible)
  end

  @doc """
  Hides the cursor.

  ## Examples

      iex> cursor = Cursor.Manager.new()
      iex> cursor = Cursor.Style.hide(cursor)
      iex> cursor.state
      :hidden
  """
  def hide(%Manager{} = cursor) do
    Manager.set_state(cursor, :hidden)
  end

  @doc """
  Makes the cursor blink.

  ## Examples

      iex> cursor = Cursor.Manager.new()
      iex> cursor = Cursor.Style.blink(cursor)
      iex> cursor.state
      :blinking
  """
  def blink(%Manager{} = cursor) do
    Manager.set_state(cursor, :blinking)
  end

  @doc """
  Sets the cursor blink rate in milliseconds.

  ## Examples

      iex> cursor = Cursor.Manager.new()
      iex> cursor = Cursor.Style.set_blink_rate(cursor, 1000)
      iex> cursor.blink_rate
      1000
  """
  def set_blink_rate(%Manager{} = cursor, rate)
      when is_integer(rate) and rate > 0 do
    %{cursor | blink_rate: rate}
  end

  @doc """
  Updates the cursor blink state and returns the updated cursor and visibility.

  ## Examples

      iex> cursor = Cursor.Manager.new()
      iex> cursor = Cursor.Style.blink(cursor)
      iex> {cursor, visible} = Cursor.Style.update_blink(cursor)
      iex> is_boolean(visible)
      true
  """
  def update_blink(%Manager{} = cursor) do
    Manager.update_blink(cursor)
  end

  @doc """
  Toggles the cursor visibility.

  ## Examples

      iex> cursor = Cursor.Manager.new()
      iex> cursor = Cursor.Style.toggle_visibility(cursor)
      iex> cursor.state
      :hidden
      iex> cursor = Cursor.Style.toggle_visibility(cursor)
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

  @doc """
  Toggles the cursor blinking state.

  ## Examples

      iex> cursor = Cursor.Manager.new()
      iex> cursor = Cursor.Style.toggle_blink(cursor)
      iex> cursor.state
      :blinking
      iex> cursor = Cursor.Style.toggle_blink(cursor)
      iex> cursor.state
      :visible
  """
  def toggle_blink(%Manager{} = cursor) do
    case cursor.state do
      :blinking -> show(cursor)
      _ -> blink(cursor)
    end
  end
end
