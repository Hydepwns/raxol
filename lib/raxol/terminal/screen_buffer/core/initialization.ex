defmodule Raxol.Terminal.ScreenBuffer.Core.Initialization do
  @moduledoc """
  Handles initialization of screen buffer instances.
  """

  alias Raxol.Terminal.ScreenBuffer.{
    Charset,
    Formatting,
    State,
    Metrics,
    FileWatcher,
    Scroll,
    Screen,
    Mode,
    Visualizer,
    Preferences,
    System,
    Cloud,
    Theme,
    CSI
  }

  defstruct [
    :cells,
    :width,
    :height,
    :charset_state,
    :formatting_state,
    :terminal_state,
    :output_buffer,
    :metrics_state,
    :file_watcher_state,
    :scroll_state,
    :screen_state,
    :mode_state,
    :visualizer_state,
    :preferences,
    :system_state,
    :cloud_state,
    :theme_state,
    :csi_state,
    :default_style
  ]

  @type t :: %__MODULE__{
          cells: list(list(map())),
          width: non_neg_integer(),
          height: non_neg_integer(),
          charset_state: map(),
          formatting_state: map(),
          terminal_state: map(),
          output_buffer: String.t(),
          metrics_state: map(),
          file_watcher_state: map(),
          scroll_state: map(),
          screen_state: map(),
          mode_state: map(),
          visualizer_state: map(),
          preferences: map(),
          system_state: map(),
          cloud_state: map(),
          theme_state: map(),
          csi_state: map(),
          default_style: map()
        }

  @doc """
  Creates a new screen buffer with the specified dimensions.
  """
  def new(width, height, _scrollback \\ 1000) do
    %__MODULE__{
      cells:
        List.duplicate(List.duplicate(Raxol.Terminal.Cell.new(), width), height),
      width: width,
      height: height,
      charset_state: Charset.init(),
      formatting_state: Formatting.init(),
      terminal_state: State.init(),
      output_buffer: "",
      metrics_state: Metrics.init(),
      file_watcher_state: FileWatcher.init(),
      scroll_state: Scroll.init(),
      screen_state: Screen.init(),
      mode_state: Mode.init(),
      visualizer_state: Visualizer.init(),
      preferences: Preferences.init(),
      system_state: System.init(),
      cloud_state: Cloud.init(),
      theme_state: Theme.init(),
      csi_state: CSI.init(),
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
end
