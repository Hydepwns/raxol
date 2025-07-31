defmodule Raxol.Test.Support.Mocks.BufferManagerMock do
  @moduledoc """
  Mock implementation for Raxol.Terminal.Buffer.Manager.Behaviour
  """

  @behaviour Raxol.Terminal.Buffer.Manager.Behaviour

  def initialize_buffers(width, height, _buffer_type, _opts \\ []) do
    %{
      main: %{width: width, height: height, cells: []},
      alternate: %{width: width, height: height, cells: []}
    }
  end

  def write(_buffer, _data, _opts), do: :ok
  def read(_buffer, _opts), do: {:ok, ""}
  def resize(_buffer, _width, _height), do: :ok
  def scroll(_buffer, _lines), do: :ok
  def set_cell(_buffer, _x, _y, _cell), do: :ok
  def get_cell(_x, _y, _buffer), do: %{char: " ", style: %{}}
  def clear_damage(_buffer), do: :ok
  def get_memory_usage(_buffer), do: 0
  def get_metrics(_buffer), do: %{}
  def get_scrollback_count(_buffer), do: 0
end

defmodule Raxol.Test.Support.Mocks.BufferScrollbackMock do
  @moduledoc """
  Mock implementation for Raxol.Terminal.Buffer.Scrollback.Behaviour
  """

  @behaviour Raxol.Terminal.Buffer.Scrollback.Behaviour

  def new do
    %{lines: [], max_lines: 1000}
  end

  def add_line(_buffer, _line), do: :ok
  def get_lines(_buffer), do: []
end

defmodule Raxol.Test.Support.Mocks.BufferScrollRegionMock do
  @moduledoc """
  Mock implementation for Raxol.Terminal.Buffer.ScrollRegion.Behaviour
  """

  @behaviour Raxol.Terminal.Buffer.ScrollRegion.Behaviour

  def new do
    %{top: 0, bottom: 0}
  end

  def get_region(_buffer), do: {0, 0}
  def set_region(_buffer, _region), do: :ok
end

defmodule Raxol.Test.Support.Mocks.BufferSelectionMock do
  @moduledoc """
  Mock implementation for Raxol.Terminal.Buffer.Selection.Behaviour
  """

  @behaviour Raxol.Terminal.Buffer.Selection.Behaviour

  def new do
    %{start: nil, end: nil, active: false}
  end

  def get_selection(_buffer), do: nil
  def set_selection(_buffer, _start, _end), do: :ok
end

defmodule Raxol.Test.Support.Mocks.BufferQueriesMock do
  @moduledoc """
  Mock implementation for Raxol.Terminal.Buffer.Queries.Behaviour
  """

  @behaviour Raxol.Terminal.Buffer.Queries.Behaviour

  def get_dimensions(_buffer), do: {80, 24}
  def get_width(_buffer), do: 80
  def get_height(_buffer), do: 24
  def get_content(_buffer), do: []
  def get_line(_buffer, _y), do: []
  def get_cell(_buffer, _x, _y), do: %{char: " ", style: %{}}
  def get_text(_buffer), do: ""
  def get_line_text(_buffer, _y), do: ""
  def in_bounds?(_buffer, _x, _y), do: true
  def empty?(_buffer), do: true
  def get_char(_buffer, _x, _y), do: " "
end

defmodule Raxol.Test.Support.Mocks.BufferLineOperationsMock do
  @moduledoc """
  Mock implementation for Raxol.Terminal.Buffer.LineOperations.Behaviour
  """

  @behaviour Raxol.Terminal.Buffer.LineOperations.Behaviour

  def insert_line(buffer, _y), do: buffer
  def delete_line(buffer, _y), do: buffer
  def get_line(_buffer, _y), do: []
  def set_line(_buffer, _y, _line), do: :ok
  def insert_lines(_buffer, _y, _count), do: :ok
  def delete_lines(_buffer, _y, _count), do: :ok
  def delete_lines(_buffer, _y, _count, _opts), do: :ok
  def delete_lines(_buffer, _start_x, _start_y, _end_x, _end_y), do: :ok
  def pop_top_lines(buffer, _count), do: {[], buffer}
  def prepend_lines(_buffer, _lines), do: :ok
end
