defmodule Raxol.Terminal.ScreenBuffer.Core.Initialization do
  @moduledoc """
  Handles initialization of screen buffer instances.
  """

  alias Raxol.Terminal.ScreenBuffer.{
    Charset,
    Formatting,
    Metrics,
    Scroll,
    Screen,
    Mode,
    Preferences,
    CSI
  }

  alias Raxol.Terminal.ScreenBuffer.Core

  @doc """
  Creates a new screen buffer with the specified dimensions.
  """
  def new(width, height, scrollback \\ 1000)
  def new(width, height, _scrollback) when width > 0 and height > 0 do
    %Core{
      cells:
        List.duplicate(List.duplicate(Raxol.Terminal.Cell.new(), width), height),
      width: width,
      height: height,
      charset_state: safe_init(Charset),
      formatting_state: safe_init(Formatting),
      terminal_state: %{},
      output_buffer: "",
      metrics_state: safe_init(Metrics),
      file_watcher_state: %{},
      scroll_state: safe_init(Scroll),
      screen_state: safe_init(Screen),
      mode_state: safe_init(Mode),
      visualizer_state: %{},
      preferences: safe_init(Preferences),
      system_state: %{},
      cloud_state: %{},
      theme_state: %{},
      csi_state: safe_init(CSI),
      default_style: %{
        foreground: nil,
        background: nil,
        bold: false,
        italic: false,
        underline: false,
        blink: false,
        reverse: false,
        hidden: false,
        strikethrough: false
      }
    }
  end

  def new(_width, _height, _scrollback) do
    # Invalid dimensions, return minimal buffer
    %Core{
      cells: [],
      width: 0,
      height: 0,
      charset_state: %{},
      formatting_state: %{},
      terminal_state: %{},
      output_buffer: "",
      metrics_state: %{},
      file_watcher_state: %{},
      scroll_state: %{},
      screen_state: %{},
      mode_state: %{},
      visualizer_state: %{},
      preferences: %{},
      system_state: %{},
      cloud_state: %{},
      theme_state: %{},
      csi_state: %{},
      default_style: %{}
    }
  end

  # Safe initialization helper
  defp safe_init(module) do
    if function_exported?(module, :init, 0) do
      apply(module, :init, [])
    else
      %{}
    end
  rescue
    _ -> %{}
  end
end
