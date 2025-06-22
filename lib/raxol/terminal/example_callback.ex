defmodule Raxol.Terminal.ExampleCallback do
  @moduledoc """
  Example implementation of Raxol.Terminal.Manager.Callback.
  This module logs each event it receives. Use as a template for your own callback modules.
  """
  @behaviour Raxol.Terminal.Manager.Callback

  require Raxol.Core.Runtime.Log

  def focus_changed(focused, _state) do
    Raxol.Core.Runtime.Log.info(
      "[ExampleCallback] Focus changed: #{inspect(focused)}"
    )
  end

  def resized(width, height, _state) do
    Raxol.Core.Runtime.Log.info(
      "[ExampleCallback] Terminal resized: #{width}x#{height}"
    )
  end

  def mode_changed(mode, _state) do
    Raxol.Core.Runtime.Log.info(
      "[ExampleCallback] Mode changed: #{inspect(mode)}"
    )
  end

  def clipboard_event(op, content, _state) do
    Raxol.Core.Runtime.Log.info(
      "[ExampleCallback] Clipboard event: #{inspect(op)} #{inspect(content)}"
    )
  end

  def selection_changed(selection, _state) do
    Raxol.Core.Runtime.Log.info(
      "[ExampleCallback] Selection changed: #{inspect(selection)}"
    )
  end

  def paste_event(text, pos, _state) do
    Raxol.Core.Runtime.Log.info(
      "[ExampleCallback] Paste event: #{inspect(text)} at #{inspect(pos)}"
    )
  end

  def cursor_event(cursor, _state) do
    Raxol.Core.Runtime.Log.info(
      "[ExampleCallback] Cursor event: #{inspect(cursor)}"
    )
  end

  def scroll_event(dir, delta, pos, _state) do
    Raxol.Core.Runtime.Log.info(
      "[ExampleCallback] Scroll event: #{inspect(dir)} delta=#{delta} at #{inspect(pos)}"
    )
  end
end
