defmodule Raxol.Terminal.Commands.CSIHandlers.HandlerFactory do
  @moduledoc """
  Factory functions for creating CSI command handlers.
  """

  def csi_command_handlers do
    [
      {:cursor_up,
       &Raxol.Terminal.Commands.CSIHandlers.CursorMovement.handle_cursor_up/2},
      {:cursor_down,
       &Raxol.Terminal.Commands.CSIHandlers.CursorMovement.handle_cursor_down/2},
      {:cursor_forward,
       &Raxol.Terminal.Commands.CSIHandlers.CursorMovement.handle_cursor_forward/2},
      {:cursor_backward,
       &Raxol.Terminal.Commands.CSIHandlers.CursorMovement.handle_cursor_backward/2},
      {:cursor_position,
       &Raxol.Terminal.Commands.CSIHandlers.CursorMovement.handle_cursor_position/2,
       :with_params},
      {:cursor_column,
       &Raxol.Terminal.Commands.CSIHandlers.CursorMovement.handle_cursor_column/2},
      {:screen_clear,
       &Raxol.Terminal.Commands.CSIHandlers.ScreenHandlers.handle_screen_clear/2,
       :with_params},
      {:line_clear,
       &Raxol.Terminal.Commands.CSIHandlers.ScreenHandlers.handle_erase_line/2,
       0},
      {:text_attributes,
       &Raxol.Terminal.Commands.CSIHandlers.TextHandlers.handle_text_attributes/2,
       :with_params},
      {:scroll_up,
       &Raxol.Terminal.Commands.CSIHandlers.ScreenHandlers.handle_scroll_up/2},
      {:scroll_down,
       &Raxol.Terminal.Commands.CSIHandlers.ScreenHandlers.handle_scroll_down/2},
      {:device_status,
       &Raxol.Terminal.Commands.CSIHandlers.DeviceHandlers.handle_device_status/2,
       :with_params},
      {:save_restore_cursor,
       &Raxol.Terminal.Commands.CSIHandlers.TextHandlers.handle_save_restore_cursor/2,
       :with_params}
    ]
    |> Enum.map(fn
      {key, fun} -> {key, create_handler(fun)}
      {key, fun, :with_params} -> {key, create_handler_with_params(fun)}
      {key, fun, default} -> {key, create_handler(fun, default)}
    end)
    |> Map.new()
  end

  # Helper functions for creating handlers
  defp create_handler(fun) do
    fn emulator, params ->
      fun.(emulator, params)
    end
  end

  defp create_handler(fun, default) do
    fn emulator, params ->
      case params do
        [] -> fun.(emulator, default)
        [param] -> fun.(emulator, param)
        _ -> fun.(emulator, params)
      end
    end
  end

  defp create_handler_with_params(fun) do
    fn emulator, params ->
      fun.(emulator, params)
    end
  end
end
