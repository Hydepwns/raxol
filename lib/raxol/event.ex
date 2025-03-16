defmodule Raxol.Event do
  @moduledoc """
  Event handling and conversion utilities.
  
  This module handles conversion between ex_termbox events and Raxol
  events, as well as providing utilities for event handling.
  """
  
  @doc """
  Converts an ex_termbox event to a Raxol event.
  
  ## Parameters
  
  * `event` - An ex_termbox event tuple
  
  ## Returns
  
  A Raxol event map.
  
  ## Example
  
  ```elixir
  event = Raxol.Event.convert({:key, :none, ?a})
  # Returns %{type: :key, meta: :none, key: ?a}
  ```
  """
  def convert({:key, meta, key}) do
    # Convert key code to a more friendly format if possible
    key = convert_key(key)
    
    %{
      type: :key,
      meta: meta,
      key: key
    }
  end
  
  def convert({:resize, width, height}) do
    %{
      type: :resize,
      width: width,
      height: height
    }
  end
  
  def convert({:mouse, button, x, y, meta}) do
    %{
      type: :mouse,
      button: button,
      x: x,
      y: y,
      meta: meta
    }
  end
  
  def convert(event) do
    %{
      type: :unknown,
      raw: event
    }
  end
  
  @doc """
  Checks if a key combination matches the given event.
  
  ## Parameters
  
  * `event` - A Raxol event map
  * `meta` - The meta key (:ctrl, :shift, :alt, or :none)
  * `key` - The key to match (character code or named key)
  
  ## Returns
  
  `true` if the event matches, `false` otherwise.
  
  ## Example
  
  ```elixir
  Raxol.Event.key_match?(event, :ctrl, ?c)
  # Returns true for Ctrl+C
  ```
  """
  def key_match?(%{type: :key, meta: event_meta, key: event_key}, meta, key) do
    event_meta == meta && event_key == key
  end
  
  def key_match?(_, _, _), do: false
  
  @doc """
  Checks if an event is a specific key press.
  
  ## Parameters
  
  * `event` - A Raxol event map
  * `key` - The key to match (character code or named key)
  
  ## Returns
  
  `true` if the event matches, `false` otherwise.
  
  ## Example
  
  ```elixir
  Raxol.Event.key?(event, :enter)
  # Returns true for Enter key press
  ```
  """
  def key?(%{type: :key, key: event_key}, key) do
    event_key == key
  end
  
  def key?(_, _), do: false
  
  @doc """
  Checks if an event is a Ctrl+Key combination.
  
  ## Parameters
  
  * `event` - A Raxol event map
  * `key` - The key to match (character code or named key)
  
  ## Returns
  
  `true` if the event matches, `false` otherwise.
  
  ## Example
  
  ```elixir
  Raxol.Event.ctrl_key?(event, ?c)
  # Returns true for Ctrl+C
  ```
  """
  def ctrl_key?(%{type: :key, meta: :ctrl, key: event_key}, key) do
    event_key == key
  end
  
  def ctrl_key?(_, _), do: false
  
  @doc """
  Checks if an event is a Shift+Key combination.
  
  ## Parameters
  
  * `event` - A Raxol event map
  * `key` - The key to match (character code or named key)
  
  ## Returns
  
  `true` if the event matches, `false` otherwise.
  
  ## Example
  
  ```elixir
  Raxol.Event.shift_key?(event, :tab)
  # Returns true for Shift+Tab
  ```
  """
  def shift_key?(%{type: :key, meta: :shift, key: event_key}, key) do
    event_key == key
  end
  
  def shift_key?(_, _), do: false
  
  @doc """
  Checks if an event is a mouse click.
  
  ## Parameters
  
  * `event` - A Raxol event map
  * `button` - The button to match (:left, :right, :middle, or any)
  
  ## Returns
  
  `true` if the event matches, `false` otherwise.
  
  ## Example
  
  ```elixir
  Raxol.Event.mouse_click?(event, :left)
  # Returns true for left mouse click
  ```
  """
  def mouse_click?(%{type: :mouse, button: event_button}, button) do
    event_button == button
  end
  
  def mouse_click?(%{type: :mouse}, :any), do: true
  
  def mouse_click?(_, _), do: false
  
  @doc """
  Checks if an event is a resize event.
  
  ## Parameters
  
  * `event` - A Raxol event map
  
  ## Returns
  
  `true` if the event is a resize event, `false` otherwise.
  
  ## Example
  
  ```elixir
  Raxol.Event.resize?(event)
  # Returns true for terminal resize events
  ```
  """
  def resize?(%{type: :resize}), do: true
  def resize?(_), do: false
  
  # Private functions
  
  # Convert numeric key codes to named keys
  defp convert_key(13), do: :enter
  defp convert_key(9), do: :tab
  defp convert_key(27), do: :escape
  defp convert_key(32), do: :space
  defp convert_key(127), do: :backspace
  defp convert_key(8), do: :backspace
  defp convert_key(263), do: :backspace
  defp convert_key(330), do: :delete
  defp convert_key(259), do: :arrow_up
  defp convert_key(258), do: :arrow_down
  defp convert_key(260), do: :arrow_left
  defp convert_key(261), do: :arrow_right
  defp convert_key(262), do: :home
  defp convert_key(360), do: :end
  defp convert_key(339), do: :page_up
  defp convert_key(338), do: :page_down
  defp convert_key(key) when key in ?a..?z and is_integer(key), do: key
  defp convert_key(key) when key in ?A..?Z and is_integer(key), do: key
  defp convert_key(key) when key in ?0..?9 and is_integer(key), do: key
  defp convert_key(key), do: key
end 