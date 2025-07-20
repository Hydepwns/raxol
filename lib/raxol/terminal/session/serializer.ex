defmodule Raxol.Terminal.Session.Serializer do
  @moduledoc """
  Handles serialization and deserialization of terminal session state.
  """

  alias Raxol.Terminal.{Session, Renderer, ScreenBuffer, Emulator}
  require Raxol.Core.Runtime.Log

  @doc """
  Serializes a session state to a map that can be stored and later restored.
  """
  @spec serialize(Session.t()) :: map()
  def serialize(%Session{} = session) do
    try do
      %{
        id: session.id,
        width: session.width,
        height: session.height,
        title: session.title,
        theme: session.theme,
        auto_save: session.auto_save,
        emulator: serialize_emulator(session.emulator),
        renderer: serialize_renderer(session.renderer)
      }
    rescue
      e ->
        Raxol.Core.Runtime.Log.error(
          "Session serialization failed: #{inspect(e)}"
        )

        Raxol.Core.Runtime.Log.error(
          "Stacktrace: #{Exception.format_stacktrace(__STACKTRACE__)}"
        )

        reraise e, __STACKTRACE__
    end
  end

  @doc """
  Deserializes a session state from a map.
  """
  @spec deserialize(map()) :: {:ok, Session.t()} | {:error, term()}
  def deserialize(%{
        id: id,
        width: width,
        height: height,
        title: title,
        theme: theme,
        auto_save: auto_save,
        emulator: emulator_data,
        renderer: renderer_data
      }) do
    with {:ok, emulator} <- deserialize_emulator(emulator_data),
         {:ok, renderer} <- deserialize_renderer(renderer_data) do
      session = %Session{
        id: id,
        width: width,
        height: height,
        title: title,
        theme: theme,
        auto_save: auto_save,
        emulator: emulator,
        renderer: renderer
      }

      {:ok, session}
    end
  end

  def deserialize(invalid_data) do
    Raxol.Core.Runtime.Log.error(
      "Invalid session data: #{inspect(invalid_data)}"
    )

    {:error, :invalid_session_data}
  end

  defp serialize_emulator(%Emulator{} = emulator) do
    %{
      main_screen_buffer: serialize_screen_buffer(emulator.main_screen_buffer),
      alternate_screen_buffer:
        serialize_screen_buffer(emulator.alternate_screen_buffer),
      active_buffer_type: emulator.active_buffer_type,
      scrollback_buffer: serialize_screen_buffer(emulator.scrollback_buffer),
      cursor: emulator.cursor,
      mode_manager: emulator.mode_manager,
      style: emulator.style,
      charset_state: emulator.charset_state,
      width: emulator.width,
      height: emulator.height,
      window_state: emulator.window_state,
      state_stack: emulator.state_stack,
      output_buffer: emulator.output_buffer,
      scrollback_limit: emulator.scrollback_limit,
      window_title: emulator.window_title,
      plugin_manager: emulator.plugin_manager,
      saved_cursor: emulator.saved_cursor,
      scroll_region: emulator.scroll_region,
      sixel_state: emulator.sixel_state,
      last_col_exceeded: emulator.last_col_exceeded,
      cursor_blink_rate: emulator.cursor_blink_rate,
      cursor_style: emulator.cursor_style,
      session_id: emulator.session_id,
      client_options: emulator.client_options
    }
  end

  defp serialize_renderer(%Renderer{} = renderer) do
    %{
      screen_buffer: serialize_screen_buffer(renderer.screen_buffer),
      theme: renderer.theme
    }
  end

  defp serialize_screen_buffer(%ScreenBuffer{} = buffer) do
    try do
      %{
        width: buffer.width,
        height: buffer.height,
        cells: serialize_cells(buffer.cells),
        cursor_position: buffer.cursor_position
      }
    rescue
      e ->
        Raxol.Core.Runtime.Log.error(
          "ScreenBuffer serialization failed: #{inspect(e)}"
        )

        Raxol.Core.Runtime.Log.error(
          "Stacktrace: #{Exception.format_stacktrace(__STACKTRACE__)}"
        )

        reraise e, __STACKTRACE__
    end
  end

  defp serialize_screen_buffer([]) do
    []
  end

  defp serialize_screen_buffer(buffers) when is_list(buffers) do
    Enum.map(buffers, &serialize_screen_buffer/1)
  end

  defp serialize_cells(cells) when is_list(cells) do
    try do
      Enum.map(cells, fn row ->
        Enum.map(row, &serialize_cell/1)
      end)
    rescue
      e ->
        Raxol.Core.Runtime.Log.error(
          "Cells serialization failed: #{inspect(e)}"
        )

        Raxol.Core.Runtime.Log.error(
          "Stacktrace: #{Exception.format_stacktrace(__STACKTRACE__)}"
        )

        reraise e, __STACKTRACE__
    end
  end

  defp serialize_cell(%Raxol.Terminal.Cell{} = cell) do
    try do
      %{
        char: cell.char,
        style: serialize_style(cell.style),
        dirty: cell.dirty,
        wide_placeholder: cell.wide_placeholder
      }
    rescue
      e ->
        Raxol.Core.Runtime.Log.error("Cell serialization failed: #{inspect(e)}")
        Raxol.Core.Runtime.Log.error("Cell data: #{inspect(cell)}")

        Raxol.Core.Runtime.Log.error(
          "Stacktrace: #{Exception.format_stacktrace(__STACKTRACE__)}"
        )

        reraise e, __STACKTRACE__
    end
  end

  defp serialize_style(%Raxol.Terminal.ANSI.TextFormatting.Core{} = style) do
    try do
      %{
        bold: style.bold,
        italic: style.italic,
        underline: style.underline,
        blink: style.blink,
        reverse: style.reverse,
        foreground: style.foreground,
        background: style.background,
        double_width: style.double_width,
        double_height: style.double_height,
        faint: style.faint,
        conceal: style.conceal,
        strikethrough: style.strikethrough,
        fraktur: style.fraktur,
        double_underline: style.double_underline,
        framed: style.framed,
        encircled: style.encircled,
        overlined: style.overlined,
        hyperlink: style.hyperlink
      }
    rescue
      e ->
        Raxol.Core.Runtime.Log.error(
          "Style serialization failed: #{inspect(e)}"
        )

        Raxol.Core.Runtime.Log.error("Style data: #{inspect(style)}")

        Raxol.Core.Runtime.Log.error(
          "Stacktrace: #{Exception.format_stacktrace(__STACKTRACE__)}"
        )

        reraise e, __STACKTRACE__
    end
  end

  # Handle nil style values
  defp serialize_style(nil) do
    %{
      bold: false,
      italic: false,
      underline: false,
      blink: false,
      reverse: false,
      foreground: nil,
      background: nil,
      double_width: false,
      double_height: :none,
      faint: false,
      conceal: false,
      strikethrough: false,
      fraktur: false,
      double_underline: false,
      framed: false,
      encircled: false,
      overlined: false,
      hyperlink: nil
    }
  end

  # Backward compatibility for old TextFormatting struct
  defp serialize_style(%Raxol.Terminal.ANSI.TextFormatting{} = style) do
    try do
      %{
        bold: style.bold,
        italic: style.italic,
        underline: style.underline,
        blink: style.blink,
        reverse: style.reverse,
        foreground: style.foreground,
        background: style.background,
        double_width: style.double_width,
        double_height: style.double_height,
        faint: style.faint,
        conceal: style.conceal,
        strikethrough: style.strikethrough,
        fraktur: style.fraktur,
        double_underline: style.double_underline,
        framed: style.framed,
        encircled: style.encircled,
        overlined: style.overlined,
        hyperlink: style.hyperlink
      }
    rescue
      e ->
        Raxol.Core.Runtime.Log.error(
          "Style serialization failed: #{inspect(e)}"
        )

        Raxol.Core.Runtime.Log.error("Style data: #{inspect(style)}")

        Raxol.Core.Runtime.Log.error(
          "Stacktrace: #{Exception.format_stacktrace(__STACKTRACE__)}"
        )

        reraise e, __STACKTRACE__
    end
  end

  # Catch-all for any other style values
  defp serialize_style(style) do
    Raxol.Core.Runtime.Log.warning(
      "Unknown style type encountered during serialization: #{inspect(style)}"
    )

    # Return default style
    serialize_style(nil)
  end

  defp deserialize_emulator(emulator_data) do
    with {:ok, main_screen_buffer} <-
           deserialize_screen_buffer(emulator_data.main_screen_buffer),
         {:ok, alternate_screen_buffer} <-
           deserialize_screen_buffer(emulator_data.alternate_screen_buffer),
         {:ok, scrollback_buffer} <-
           deserialize_screen_buffer(emulator_data.scrollback_buffer) do
      emulator = %Emulator{
        main_screen_buffer: main_screen_buffer,
        alternate_screen_buffer: alternate_screen_buffer,
        active_buffer_type: emulator_data.active_buffer_type,
        scrollback_buffer: scrollback_buffer,
        cursor: emulator_data.cursor,
        mode_manager: emulator_data.mode_manager,
        style: emulator_data.style,
        charset_state: emulator_data.charset_state,
        width: emulator_data.width,
        height: emulator_data.height,
        window_state: emulator_data.window_state,
        state_stack: emulator_data.state_stack,
        output_buffer: emulator_data.output_buffer,
        scrollback_limit: emulator_data.scrollback_limit,
        window_title: emulator_data.window_title,
        plugin_manager: emulator_data.plugin_manager,
        saved_cursor: emulator_data.saved_cursor,
        scroll_region: emulator_data.scroll_region,
        sixel_state: emulator_data.sixel_state,
        last_col_exceeded: emulator_data.last_col_exceeded,
        cursor_blink_rate: emulator_data.cursor_blink_rate,
        cursor_style: emulator_data.cursor_style,
        session_id: emulator_data.session_id,
        client_options: emulator_data.client_options
      }

      {:ok, emulator}
    end
  end

  defp deserialize_renderer(%{screen_buffer: buffer_data, theme: theme}) do
    with {:ok, screen_buffer} <- deserialize_screen_buffer(buffer_data) do
      renderer = %Renderer{
        screen_buffer: screen_buffer,
        theme: theme
      }

      {:ok, renderer}
    end
  end

  defp deserialize_screen_buffer(%{
         width: width,
         height: height,
         cells: cells,
         cursor_position: cursor_position
       }) do
    deserialized_cells = deserialize_cells(cells)

    screen_buffer = %ScreenBuffer{
      width: width,
      height: height,
      cells: deserialized_cells,
      cursor_position: cursor_position,
      scrollback: [],
      scrollback_limit: 1000,
      selection: nil,
      scroll_region: nil,
      scroll_position: 0,
      damage_regions: [],
      default_style: Raxol.Terminal.ANSI.TextFormatting.Core.new()
    }

    {:ok, screen_buffer}
  end

  defp deserialize_screen_buffer([]) do
    {:ok, []}
  end

  defp deserialize_cells(cells) when is_list(cells) do
    Enum.map(cells, fn row ->
      Enum.map(row, &deserialize_cell/1)
    end)
  end

  defp deserialize_cell(%{
         char: char,
         style: style_data,
         dirty: dirty,
         wide_placeholder: wide_placeholder
       }) do
    %Raxol.Terminal.Cell{
      char: char,
      style: deserialize_style(style_data),
      dirty: dirty,
      wide_placeholder: wide_placeholder
    }
  end

  defp deserialize_style(%{
         bold: bold,
         italic: italic,
         underline: underline,
         blink: blink,
         reverse: reverse,
         foreground: foreground,
         background: background,
         double_width: double_width,
         double_height: double_height,
         faint: faint,
         conceal: conceal,
         strikethrough: strikethrough,
         fraktur: fraktur,
         double_underline: double_underline,
         framed: framed,
         encircled: encircled,
         overlined: overlined,
         hyperlink: hyperlink
       }) do
    %Raxol.Terminal.ANSI.TextFormatting.Core{
      bold: bold,
      italic: italic,
      underline: underline,
      blink: blink,
      reverse: reverse,
      foreground: foreground,
      background: background,
      double_width: double_width,
      double_height: double_height,
      faint: faint,
      conceal: conceal,
      strikethrough: strikethrough,
      fraktur: fraktur,
      double_underline: double_underline,
      framed: framed,
      encircled: encircled,
      overlined: overlined,
      hyperlink: hyperlink
    }
  end

  # Handle nil style values
  defp deserialize_style(nil) do
    Raxol.Terminal.ANSI.TextFormatting.Core.new()
  end

  # Catch-all for any other style values
  defp deserialize_style(style) do
    Raxol.Core.Runtime.Log.warning(
      "Unknown style type encountered during deserialization: #{inspect(style)}"
    )

    # Return default style
    Raxol.Terminal.ANSI.TextFormatting.Core.new()
  end
end
