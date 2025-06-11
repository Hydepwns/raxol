defmodule Raxol.Terminal.NotificationManager do
  @moduledoc """
  Manages terminal notifications, telemetry events, and callbacks.

  This module is responsible for:
  - Sending notifications to runtime processes
  - Emitting telemetry events
  - Managing callback execution
  - Logging notification events
  """

  require Raxol.Core.Runtime.Log

  @doc """
  Notifies about a focus change event.

  ## Parameters
    * `runtime_pid` - The PID of the runtime process to notify
    * `callback_module` - The callback module to execute
    * `focused?` - Whether the terminal is focused
  """
  @spec notify_focus_changed(pid() | nil, module() | nil, boolean()) :: :ok
  def notify_focus_changed(runtime_pid, callback_module, focused?) do
    if runtime_pid,
      do: send(runtime_pid, {:terminal_focus_changed, focused?})

    Raxol.Core.Runtime.Log.info("Terminal focus changed: #{inspect(focused?)}")

    :telemetry.execute(
      [:raxol, :terminal, :focus_changed],
      %{focused: focused?},
      %{pid: self()}
    )

    if callback_module,
      do: apply(callback_module, :focus_changed, [focused?, %{}])

    :ok
  end

  @doc """
  Notifies about a terminal resize event.

  ## Parameters
    * `runtime_pid` - The PID of the runtime process to notify
    * `callback_module` - The callback module to execute
    * `width` - The new width
    * `height` - The new height
  """
  @spec notify_resized(pid() | nil, module() | nil, integer(), integer()) :: :ok
  def notify_resized(runtime_pid, callback_module, width, height) do
    if runtime_pid,
      do: send(runtime_pid, {:terminal_resized, width, height})

    Raxol.Core.Runtime.Log.info("Terminal resized: #{width}x#{height}")

    :telemetry.execute(
      [:raxol, :terminal, :resized],
      %{width: width, height: height},
      %{pid: self()}
    )

    if callback_module,
      do: apply(callback_module, :resized, [width, height, %{}])

    :ok
  end

  @doc """
  Notifies about a mode change event.

  ## Parameters
    * `runtime_pid` - The PID of the runtime process to notify
    * `callback_module` - The callback module to execute
    * `new_mode` - The new mode
  """
  @spec notify_mode_changed(pid() | nil, module() | nil, atom()) :: :ok
  def notify_mode_changed(runtime_pid, callback_module, new_mode) do
    if runtime_pid,
      do: send(runtime_pid, {:terminal_mode_changed, new_mode})

    Raxol.Core.Runtime.Log.info("Terminal mode changed: #{inspect(new_mode)}")

    :telemetry.execute(
      [:raxol, :terminal, :mode_changed],
      %{mode: new_mode},
      %{pid: self()}
    )

    if callback_module,
      do: apply(callback_module, :mode_changed, [new_mode, %{}])

    :ok
  end

  @doc """
  Notifies about a clipboard event.

  ## Parameters
    * `runtime_pid` - The PID of the runtime process to notify
    * `callback_module` - The callback module to execute
    * `type` - The clipboard operation type
    * `data` - The clipboard data
  """
  @spec notify_clipboard_event(pid() | nil, module() | nil, atom(), any()) :: :ok
  def notify_clipboard_event(runtime_pid, callback_module, type, data) do
    if runtime_pid,
      do: send(runtime_pid, {:terminal_clipboard_event, type, data})

    Raxol.Core.Runtime.Log.info(
      "Terminal clipboard event: #{inspect(type)} #{inspect(data)}"
    )

    :telemetry.execute(
      [:raxol, :terminal, :clipboard_event],
      %{op: type, content: data},
      %{pid: self()}
    )

    if callback_module,
      do: apply(callback_module, :clipboard_event, [type, data, %{}])

    :ok
  end

  @doc """
  Notifies about a selection change event.

  ## Parameters
    * `runtime_pid` - The PID of the runtime process to notify
    * `callback_module` - The callback module to execute
    * `selection` - The selection data
  """
  @spec notify_selection_changed(pid() | nil, module() | nil, map()) :: :ok
  def notify_selection_changed(runtime_pid, callback_module, selection) do
    if runtime_pid,
      do: send(runtime_pid, {:terminal_selection_changed, selection})

    Raxol.Core.Runtime.Log.info(
      "Terminal selection changed: #{inspect(selection)}"
    )

    :telemetry.execute(
      [:raxol, :terminal, :selection_changed],
      %{selection: selection},
      %{pid: self()}
    )

    if callback_module,
      do: apply(callback_module, :selection_changed, [selection, %{}])

    :ok
  end

  @doc """
  Notifies about a paste event.

  ## Parameters
    * `runtime_pid` - The PID of the runtime process to notify
    * `callback_module` - The callback module to execute
    * `text` - The pasted text
    * `pos` - The paste position
  """
  @spec notify_paste_event(pid() | nil, module() | nil, String.t(), {integer(), integer()}) :: :ok
  def notify_paste_event(runtime_pid, callback_module, text, pos) do
    if runtime_pid,
      do: send(runtime_pid, {:terminal_paste_event, text, pos})

    Raxol.Core.Runtime.Log.info(
      "Terminal paste event: #{inspect(text)} at #{inspect(pos)}"
    )

    :telemetry.execute(
      [:raxol, :terminal, :paste_event],
      %{text: text, position: pos},
      %{pid: self()}
    )

    # Advanced Prometheus metric: paste length
    :telemetry.execute(
      [:raxol, :terminal, :paste_event, :length],
      %{length: String.length(text)},
      %{position: pos, pid: self()}
    )

    if callback_module,
      do: apply(callback_module, :paste_event, [text, pos, %{}])

    :ok
  end

  @doc """
  Notifies about a cursor event.

  ## Parameters
    * `runtime_pid` - The PID of the runtime process to notify
    * `callback_module` - The callback module to execute
    * `cursor` - The cursor data
  """
  @spec notify_cursor_event(pid() | nil, module() | nil, map()) :: :ok
  def notify_cursor_event(runtime_pid, callback_module, cursor) do
    if runtime_pid,
      do: send(runtime_pid, {:terminal_cursor_event, cursor})

    Raxol.Core.Runtime.Log.info("Terminal cursor event: #{inspect(cursor)}")

    :telemetry.execute(
      [:raxol, :terminal, :cursor_event],
      %{cursor: cursor},
      %{pid: self()}
    )

    if callback_module,
      do: apply(callback_module, :cursor_event, [cursor, %{}])

    :ok
  end

  @doc """
  Notifies about a scroll event.

  ## Parameters
    * `runtime_pid` - The PID of the runtime process to notify
    * `callback_module` - The callback module to execute
    * `dir` - The scroll direction
    * `delta` - The scroll delta
    * `pos` - The scroll position
  """
  @spec notify_scroll_event(pid() | nil, module() | nil, atom(), integer(), {integer(), integer()}) :: :ok
  def notify_scroll_event(runtime_pid, callback_module, dir, delta, pos) do
    if runtime_pid,
      do: send(runtime_pid, {:terminal_scroll_event, dir, delta, pos})

    Raxol.Core.Runtime.Log.info(
      "Terminal scroll event: #{inspect(dir)} delta=#{delta} at #{inspect(pos)}"
    )

    :telemetry.execute(
      [:raxol, :terminal, :scroll_event],
      %{direction: dir, delta: delta, position: pos},
      %{pid: self()}
    )

    # Advanced Prometheus metric: scroll delta histogram
    :telemetry.execute(
      [:raxol, :terminal, :scroll_event, :delta],
      %{delta: delta},
      %{direction: dir, position: pos, pid: self()}
    )

    if callback_module,
      do: apply(callback_module, :scroll_event, [dir, delta, pos, %{}])

    :ok
  end
end
