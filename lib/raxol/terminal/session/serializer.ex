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

        raise e
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

  # Private functions for serializing/deserializing components

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

        raise e
    end
  end

  defp serialize_screen_buffer([]) do
    # Handle empty scrollback buffer
    []
  end

  defp serialize_screen_buffer(buffers) when is_list(buffers) do
    # Handle list of screen buffers
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

        raise e
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

        raise e
    end
  end

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

        raise e
    end
  end

  defp deserialize_emulator(%{
         main_screen_buffer: main_screen_buffer_data,
         alternate_screen_buffer: alternate_screen_buffer_data,
         active_buffer_type: active_buffer_type,
         scrollback_buffer: scrollback_buffer_data,
         cursor: cursor,
         mode_manager: mode_manager,
         style: style,
         charset_state: charset_state,
         width: width,
         height: height,
         window_state: window_state,
         state_stack: state_stack,
         output_buffer: output_buffer,
         scrollback_limit: scrollback_limit,
         window_title: window_title,
         plugin_manager: plugin_manager,
         saved_cursor: saved_cursor,
         scroll_region: scroll_region,
         sixel_state: sixel_state,
         last_col_exceeded: last_col_exceeded,
         cursor_blink_rate: cursor_blink_rate,
         cursor_style: cursor_style,
         session_id: session_id,
         client_options: client_options
       }) do
    with {:ok, main_screen_buffer} <-
           deserialize_screen_buffer(main_screen_buffer_data),
         {:ok, alternate_screen_buffer} <-
           deserialize_screen_buffer(alternate_screen_buffer_data),
         {:ok, scrollback_buffer} <-
           deserialize_screen_buffer(scrollback_buffer_data) do
      emulator = %Emulator{
        main_screen_buffer: main_screen_buffer,
        alternate_screen_buffer: alternate_screen_buffer,
        active_buffer_type: active_buffer_type,
        scrollback_buffer: scrollback_buffer,
        cursor: cursor,
        mode_manager: mode_manager,
        style: style,
        charset_state: charset_state,
        width: width,
        height: height,
        window_state: window_state,
        state_stack: state_stack,
        output_buffer: output_buffer,
        scrollback_limit: scrollback_limit,
        window_title: window_title,
        plugin_manager: plugin_manager,
        saved_cursor: saved_cursor,
        scroll_region: scroll_region,
        sixel_state: sixel_state,
        last_col_exceeded: last_col_exceeded,
        cursor_blink_rate: cursor_blink_rate,
        cursor_style: cursor_style,
        session_id: session_id,
        client_options: client_options
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
    # Deserialize the cells back to Cell structs
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
      default_style: Raxol.Terminal.ANSI.TextFormatting.new()
    }

    {:ok, screen_buffer}
  end

  defp deserialize_screen_buffer([]) do
    # Handle empty scrollback buffer
    Raxol.Core.Runtime.Log.info("Deserializing empty scrollback buffer")
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
    %Raxol.Terminal.ANSI.TextFormatting{
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
end
