defmodule Raxol.Terminal.Buffer do
  @moduledoc """
  Manages the terminal buffer state and operations.
  """

  import Raxol.Guards

  alias Raxol.Terminal.ScreenBuffer
  alias Raxol.Terminal.Buffer.{Cell, TextFormatting, Operations}

  @type t :: %__MODULE__{
          width: non_neg_integer(),
          height: non_neg_integer(),
          cells: list(list(Cell.t())),
          cursor_x: non_neg_integer(),
          cursor_y: non_neg_integer(),
          scroll_region_top: non_neg_integer(),
          scroll_region_bottom: non_neg_integer(),
          damage_regions:
            list(
              {non_neg_integer(), non_neg_integer(), non_neg_integer(),
               non_neg_integer()}
            )
        }

  defstruct [
    :width,
    :height,
    :cells,
    :cursor_x,
    :cursor_y,
    :scroll_region_top,
    :scroll_region_bottom,
    :damage_regions
  ]

  @doc """
  Creates a new buffer with the specified dimensions.
  Raises ArgumentError if dimensions are invalid.
  """
  @spec new({non_neg_integer(), non_neg_integer()}) :: t()
  def new({width, height})
      when integer?(width) and integer?(height) and width > 0 and height > 0 do
    # Check for reasonable memory limits (1 million cells max)
    max_cells = 1_000_000
    total_cells = width * height

    if total_cells > max_cells do
      raise RuntimeError,
            "Buffer too large: #{width}x#{height} = #{total_cells} cells exceeds limit of #{max_cells} cells"
    end

    %__MODULE__{
      width: width,
      height: height,
      cells: create_empty_grid(width, height),
      cursor_x: 0,
      cursor_y: 0,
      scroll_region_top: 0,
      scroll_region_bottom: height - 1,
      damage_regions: []
    }
  end

  @doc """
  Creates a new buffer with default dimensions (80x24).
  """
  @spec new() :: t()
  def new() do
    new({80, 24})
  end

  def new({width, height}) when integer?(width) and integer?(height) do
    raise ArgumentError,
          "Invalid buffer dimensions: width and height must be positive integers"
  end

  def new(invalid) do
    raise ArgumentError,
          "Invalid buffer dimensions: expected {width, height} tuple, got #{inspect(invalid)}"
  end

  @doc """
  Sets a cell in the buffer at the specified coordinates.
  Raises ArgumentError if coordinates or cell data are invalid.
  """
  @spec set_cell(t(), non_neg_integer(), non_neg_integer(), Cell.t()) :: t()
  def set_cell(buffer, x, y, cell)
      when integer?(x) and integer?(y) and x >= 0 and y >= 0 and
             x < buffer.width and y < buffer.height do
    if not Cell.valid?(cell) do
      raise ArgumentError, "Invalid cell data: #{inspect(cell)}"
    end

    new_cells =
      List.update_at(buffer.cells, y, fn row ->
        List.update_at(row, x, fn _ -> cell end)
      end)

    %{buffer | cells: new_cells}
  end

  def set_cell(buffer, x, y, _cell) when integer?(x) and integer?(y) do
    raise ArgumentError,
          "Coordinates out of bounds: (#{x}, #{y}) for buffer size #{buffer.width}x#{buffer.height}"
  end

  def set_cell(_buffer, x, y, _cell) do
    raise ArgumentError,
          "Invalid coordinates: expected non-negative integers, got (#{inspect(x)}, #{inspect(y)})"
  end

  @doc """
  Gets a cell from the buffer at the specified coordinates.
  Delegates to ScreenBuffer.get_cell/3.
  """
  @spec get_cell(t(), non_neg_integer(), non_neg_integer()) :: Cell.t()
  def get_cell(buffer, x, y) do
    screen_buffer = to_screen_buffer(buffer)
    ScreenBuffer.get_cell(screen_buffer, x, y)
  end

  @doc """
  Resizes the buffer to the specified width and height.
  Delegates to ScreenBuffer.resize/3.
  """
  @spec resize(t(), non_neg_integer(), non_neg_integer()) :: t()
  def resize(buffer, width, height) when width <= 0 or height <= 0 do
    raise ArgumentError,
          "Buffer dimensions must be positive integers, got: #{width}x#{height}"
  end

  def resize(buffer, width, height) do
    screen_buffer = to_screen_buffer(buffer)
    resized_screen_buffer = ScreenBuffer.resize(screen_buffer, width, height)
    from_screen_buffer(resized_screen_buffer, buffer)
  end

  @doc """
  Writes data to the buffer at the current cursor position.
  """
  @spec write(t(), String.t(), keyword()) :: t()
  def write(buffer, data, _opts \\ []) do
    # Validate input data
    if not is_binary(data) do
      raise ArgumentError, "Invalid data: expected string, got #{inspect(data)}"
    end

    # Check for buffer overflow
    if String.length(data) > buffer.width * buffer.height do
      raise ArgumentError,
            "Buffer overflow: string length #{String.length(data)} exceeds buffer capacity #{buffer.width * buffer.height}"
    end

    screen_buffer = to_screen_buffer(buffer)

    updated_screen_buffer =
      Operations.write_string(
        screen_buffer,
        buffer.cursor_x,
        buffer.cursor_y,
        data
      )

    from_screen_buffer(updated_screen_buffer, buffer)
  end

  @doc """
  Reads data from the buffer.
  """
  @spec read(t(), keyword()) :: {String.t(), t()}
  def read(buffer, opts \\ []) do
    # Validate options
    if not is_list(opts) do
      raise ArgumentError,
            "Invalid options: expected keyword list, got #{inspect(opts)}"
    end

    # Check for invalid option keys
    valid_keys = [:line, :include_style, :region]
    invalid_keys = Enum.filter(opts, fn {key, _} -> key not in valid_keys end)

    if invalid_keys != [] do
      raise ArgumentError, "Invalid options: #{inspect(invalid_keys)}"
    end

    screen_buffer = to_screen_buffer(buffer)
    {Operations.get_content(screen_buffer), buffer}
  end

  @doc """
  Clears the buffer.
  """
  @spec clear(t(), keyword()) :: t()
  def clear(buffer, _opts \\ []) do
    screen_buffer = to_screen_buffer(buffer)

    updated_screen_buffer =
      Raxol.Terminal.Buffer.Eraser.clear_screen(screen_buffer)

    from_screen_buffer(updated_screen_buffer, buffer)
  end

  @doc """
  Sets the cursor position.
  """
  @spec set_cursor_position(t(), non_neg_integer(), non_neg_integer()) :: t()
  def set_cursor_position(buffer, x, y) do
    screen_buffer = to_screen_buffer(buffer)

    updated_screen_buffer =
      Raxol.Terminal.Buffer.Eraser.set_cursor_position(screen_buffer, x, y)

    from_screen_buffer(updated_screen_buffer, buffer)
  end

  @doc """
  Gets the current cursor position.
  """
  @spec get_cursor_position(t()) :: {non_neg_integer(), non_neg_integer()}
  def get_cursor_position(buffer) do
    screen_buffer = to_screen_buffer(buffer)
    Raxol.Terminal.Buffer.Eraser.get_cursor_position(screen_buffer)
  end

  @doc """
  Sets the scroll region.
  """
  @spec set_scroll_region(t(), non_neg_integer(), non_neg_integer()) :: t()
  def set_scroll_region(buffer, top, bottom) do
    # Validate scroll region parameters
    if top < 0 or bottom < 0 do
      raise ArgumentError,
            "Scroll region boundaries must be non-negative, got top=#{top}, bottom=#{bottom}"
    end

    if top > bottom do
      raise ArgumentError,
            "Scroll region top must be less than or equal to bottom, got top=#{top}, bottom=#{bottom}"
    end

    if bottom >= buffer.height do
      raise ArgumentError,
            "Scroll region bottom must be less than buffer height, got bottom=#{bottom}, height=#{buffer.height}"
    end

    screen_buffer = to_screen_buffer(buffer)

    updated_screen_buffer =
      Raxol.Terminal.Buffer.Eraser.set_scroll_region(screen_buffer, top, bottom)

    from_screen_buffer(updated_screen_buffer, buffer)
  end

  @doc """
  Scrolls the buffer by the specified number of lines.
  """
  @spec scroll(t(), integer()) :: t()
  def scroll(buffer, lines) do
    screen_buffer = to_screen_buffer(buffer)
    updated_screen_buffer = ScreenBuffer.scroll_up(screen_buffer, abs(lines))
    from_screen_buffer(updated_screen_buffer, buffer)
  end

  @doc """
  Updates the scroll state without moving content.
  This is a fast operation that only updates scroll position.
  """
  @spec scroll_state(t(), integer()) :: t()
  def scroll_state(buffer, _lines) do
    # Optimized: Since this is supposed to be a fast operation that only updates scroll position
    # and doesn't move content, we can just return the buffer unchanged.
    # The scroll position is typically tracked at a higher level (emulator, screen buffer, etc.)
    # rather than in the basic buffer struct.
    buffer
  end

  @doc """
  Marks a region of the buffer as damaged.
  """
  @spec mark_damaged(
          t(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer()
        ) :: t()
  def mark_damaged(buffer, x, y, width, height) do
    screen_buffer = to_screen_buffer(buffer)

    updated_screen_buffer =
      Raxol.Terminal.Buffer.Eraser.mark_damaged(
        screen_buffer,
        x,
        y,
        width,
        height
      )

    from_screen_buffer(updated_screen_buffer, buffer)
  end

  @doc """
  Gets all damaged regions in the buffer.
  """
  @spec get_damage_regions(t()) :: [
          {non_neg_integer(), non_neg_integer(), non_neg_integer(),
           non_neg_integer()}
        ]
  def get_damage_regions(buffer) do
    screen_buffer = to_screen_buffer(buffer)
    Raxol.Terminal.Buffer.Eraser.get_damage_regions(screen_buffer)
  end

  @doc """
  Adds content to the buffer at the current cursor position.

  ## Examples

      iex> buffer = Buffer.new({80, 24})
      iex> buffer = Buffer.add(buffer, "Hello, World!")
      iex> {content, _} = Buffer.read(buffer)
      iex> content
      "Hello, World!"
  """
  @spec add(t(), String.t()) :: t()
  def add(buffer, content) do
    write(buffer, content)
  end

  @doc """
  Fills a region of the buffer with a specified cell.
  Delegates to ScreenBuffer.fill_region/6.
  """
  @spec fill_region(
          t(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer(),
          Cell.t()
        ) :: t()
  def fill_region(buffer, x, y, width, height, cell) do
    screen_buffer = to_screen_buffer(buffer)

    filled_screen_buffer =
      ScreenBuffer.fill_region(screen_buffer, x, y, width, height, cell)

    from_screen_buffer(filled_screen_buffer, buffer)
  end

  # Private functions

  defp create_empty_grid(width, height) do
    for _y <- 0..(height - 1) do
      for _x <- 0..(width - 1) do
        Cell.new()
      end
    end
  end

  defp to_screen_buffer(buffer) do
    if buffer.cells == nil do
      raise RuntimeError, "Buffer cells are nil"
    end

    if buffer.width == nil do
      raise RuntimeError, "Buffer width is nil"
    end

    if buffer.height == nil do
      raise RuntimeError, "Buffer height is nil"
    end

    %ScreenBuffer{
      width: buffer.width,
      height: buffer.height,
      cells: buffer.cells,
      scroll_region: {buffer.scroll_region_top, buffer.scroll_region_bottom},
      cursor_position: {buffer.cursor_x, buffer.cursor_y},
      damage_regions: buffer.damage_regions,
      scroll_position: 0,
      scrollback: [],
      scrollback_limit: 1000,
      selection: nil,
      default_style: nil
    }
  end

  defp from_screen_buffer(screen_buffer, original_buffer) do
    {cursor_x, cursor_y} = screen_buffer.cursor_position

    # Handle case where scroll_region might be nil (e.g., after resize)
    {scroll_region_top, scroll_region_bottom} =
      case screen_buffer.scroll_region do
        nil -> {0, screen_buffer.height - 1}
        {top, bottom} -> {top, bottom}
      end

    %{
      original_buffer
      | cells: screen_buffer.cells,
        cursor_x: cursor_x,
        cursor_y: cursor_y,
        scroll_region_top: scroll_region_top,
        scroll_region_bottom: scroll_region_bottom,
        damage_regions: screen_buffer.damage_regions
    }
  end

  defp to_screen_buffer_core(buffer) do
    %Raxol.Terminal.ScreenBuffer.Core{
      width: buffer.width,
      height: buffer.height,
      cells: buffer.cells,
      charset_state: Raxol.Terminal.ScreenBuffer.Charset.init(),
      formatting_state: Raxol.Terminal.ScreenBuffer.Formatting.init(),
      terminal_state: Raxol.Terminal.ScreenBuffer.State.init(),
      output_buffer: "",
      metrics_state: Raxol.Terminal.ScreenBuffer.Metrics.init(),
      file_watcher_state: Raxol.Terminal.ScreenBuffer.FileWatcher.init(),
      scroll_state: Raxol.Terminal.ScreenBuffer.Scroll.init(),
      screen_state: Raxol.Terminal.ScreenBuffer.Screen.init(),
      mode_state: Raxol.Terminal.ScreenBuffer.Mode.init(),
      visualizer_state: Raxol.Terminal.ScreenBuffer.Visualizer.init(),
      preferences: Raxol.Terminal.ScreenBuffer.Preferences.init(),
      system_state: Raxol.Terminal.ScreenBuffer.System.init(),
      cloud_state: Raxol.Terminal.ScreenBuffer.Cloud.init(),
      theme_state: Raxol.Terminal.ScreenBuffer.Theme.init(),
      csi_state: Raxol.Terminal.ScreenBuffer.CSI.init(),
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

  defp from_screen_buffer_core(screen_buffer, original_buffer) do
    # Core ScreenBuffer doesn't have cursor_position and scroll_region fields
    # Just return the original buffer with updated cells
    %{
      original_buffer
      | cells: screen_buffer.cells
    }
  end
end
